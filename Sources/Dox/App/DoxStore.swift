import SwiftUI
import Observation
import DoxCore

/// Single source of truth for the running app.
/// Views read `config`, mutate through the helpers below, and the store persists (debounced)
/// and notifies `DockManager` so panels re-layout live while the user edits settings.
@MainActor
@Observable
final class DoxStore {
    static let shared = DoxStore()

    private(set) var config: AppConfig
    /// Docks temporarily hidden via shortcut / menu (not persisted).
    var hiddenDockIDs: Set<UUID> = []
    /// Dock selected in the settings sidebar.
    var selectedDockID: UUID?

    @ObservationIgnored private let store: ConfigStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Called after every change; DockManager subscribes to rebuild/re-layout panels.
    @ObservationIgnored var onChange: [(AppConfig) -> Void] = []

    init(store: ConfigStore = ConfigStore(fileURL: ConfigStore.defaultLocation())) {
        self.store = store
        self.config = store.load()
        self.selectedDockID = config.docks.first?.id
    }

    // MARK: Mutation

    /// Mutates the whole config.
    func update(_ change: (inout AppConfig) -> Void) {
        var c = config
        change(&c)
        guard c != config else { return }
        config = c
        changed()
    }

    /// Mutates one dock by id.
    func updateDock(_ id: UUID, _ change: (inout DockConfig) -> Void) {
        update { cfg in
            guard let i = cfg.dockIndex(id) else { return }
            change(&cfg.docks[i])
            cfg.docks[i].appearance = cfg.docks[i].appearance.sanitized()
        }
    }

    func dock(_ id: UUID?) -> DockConfig? {
        guard let id else { return nil }
        return config.docks.first { $0.id == id }
    }

    /// Two-way binding into a dock's property for settings controls.
    func binding<T>(dock id: UUID, _ keyPath: WritableKeyPath<DockConfig, T>) -> Binding<T> where T: Equatable {
        Binding(
            get: { [weak self] in
                guard let self, let d = self.dock(id) else {
                    return DockConfig(name: "")[keyPath: keyPath]
                }
                return d[keyPath: keyPath]
            },
            set: { [weak self] newValue in
                self?.updateDock(id) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    func binding<T>(_ keyPath: WritableKeyPath<AppConfig, T>) -> Binding<T> where T: Equatable {
        Binding(
            get: { [weak self] in self?.config[keyPath: keyPath] ?? AppConfig()[keyPath: keyPath] },
            set: { [weak self] newValue in self?.update { $0[keyPath: keyPath] = newValue } }
        )
    }

    // MARK: Docks

    @discardableResult
    func addDock(edge: DockEdge = .right) -> UUID {
        var dock = DockConfig(name: "Dock \(config.docks.count + 1)", edge: edge,
                              appearance: BuiltInThemes.obsidian.appearance,
                              categories: [DockCategory(name: "Obľúbené", symbol: "star.fill")])
        dock.behavior.alignment = .center
        update { $0.docks.append(dock) }
        selectedDockID = dock.id
        return dock.id
    }

    func duplicateDock(_ id: UUID) {
        guard let d = dock(id) else { return }
        let copy = d.duplicated()
        update { $0.docks.append(copy) }
        selectedDockID = copy.id
    }

    func removeDock(_ id: UUID) {
        update { $0.docks.removeAll { $0.id == id } }
        if selectedDockID == id { selectedDockID = config.docks.first?.id }
    }

    func toggleVisibility(of id: UUID) {
        if hiddenDockIDs.contains(id) { hiddenDockIDs.remove(id) } else { hiddenDockIDs.insert(id) }
        notify()
    }

    func toggleAllDocks() {
        let ids = Set(config.docks.map(\.id))
        hiddenDockIDs = hiddenDockIDs.isSuperset(of: ids) ? [] : ids
        notify()
    }

    // MARK: Themes

    func saveCurrentAppearanceAsTheme(dock id: UUID, name: String) {
        guard let d = dock(id) else { return }
        update { $0.customThemes.append(ThemePreset(name: name, appearance: d.appearance)) }
    }

    func deleteTheme(_ id: UUID) {
        update { $0.customThemes.removeAll { $0.id == id } }
    }

    // MARK: Import / export

    func replaceConfig(_ newConfig: AppConfig) {
        config = newConfig
        selectedDockID = newConfig.docks.first?.id
        changed()
    }

    // MARK: Persistence

    private func changed() {
        notify()
        saveTask?.cancel()
        let snapshot = config
        let store = store
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do { try store.save(snapshot) } catch { NSLog("Dox: failed to save config: \(error)") }
        }
    }

    private func notify() {
        for handler in onChange { handler(config) }
    }

    /// Flush pending writes (on quit).
    func saveNow() {
        saveTask?.cancel()
        try? store.save(config)
    }
}
