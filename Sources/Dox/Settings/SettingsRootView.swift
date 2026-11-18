import SwiftUI
import AppKit
import DoxCore

/// Root of the settings window: sidebar with docks + app pages, detail on the right.
@MainActor
struct SettingsRootView: View {
    @State private var confirmDeleteDockID: UUID?

    private var store: DoxStore { DoxStore.shared }
    private var router: SettingsRouter { SettingsRouter.shared }

    var body: some View {
        @Bindable var router = SettingsRouter.shared
        NavigationSplitView {
            sidebar(selection: $router.page)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 880, minHeight: 620)
        .onAppear(perform: ensurePage)
        .onChange(of: router.page) { _, page in
            if case .dock(let id)? = page { store.selectedDockID = id }
        }
        .onChange(of: store.config.docks.map(\.id)) { _, _ in ensurePage() }
        .confirmationDialog("Odstrániť dock?",
                            isPresented: Binding(get: { confirmDeleteDockID != nil },
                                                 set: { if !$0 { confirmDeleteDockID = nil } }),
                            titleVisibility: .visible) {
            Button("Odstrániť", role: .destructive) {
                if let id = confirmDeleteDockID { delete(id) }
                confirmDeleteDockID = nil
            }
            Button("Zrušiť", role: .cancel) { confirmDeleteDockID = nil }
        } message: {
            Text("Dock „\(store.dock(confirmDeleteDockID)?.name ?? "")“ a všetky jeho kategórie budú odstránené.")
        }
    }

    // MARK: Sidebar

    private func sidebar(selection: Binding<SettingsPage?>) -> some View {
        List(selection: selection) {
            Section("Docky") {
                ForEach(store.config.docks) { dock in
                    DockSidebarRow(dock: dock)
                        .tag(SettingsPage.dock(dock.id))
                        .contextMenu {
                            Button("Duplikovať") { store.duplicateDock(dock.id); selectStoreDock() }
                            Button("Odstrániť…", role: .destructive) { confirmDeleteDockID = dock.id }
                        }
                }
                .onMove { from, to in
                    store.update { $0.docks.move(fromOffsets: from, toOffset: to) }
                }
            }
            Section("Aplikácia") {
                Label("Témy", systemImage: "paintpalette.fill")
                    .tag(SettingsPage.themes)
                Label("Skratky", systemImage: "command")
                    .tag(SettingsPage.shortcuts)
                Label("Všeobecné", systemImage: "gearshape.fill")
                    .tag(SettingsPage.general)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) { sidebarFooter }
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
    }

    private var sidebarFooter: some View {
        let selectedDock: UUID? = {
            if case .dock(let id)? = router.page { return id }
            return nil
        }()
        return HStack(spacing: 2) {
            Menu {
                ForEach(DockEdge.allCases) { edge in
                    Button {
                        store.addDock(edge: edge)
                        selectStoreDock()
                    } label: {
                        Label("Nový dock – \(edge.displayName.lowercased())", systemImage: edge.symbol)
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .frame(width: 22, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Pridať dock")

            Button {
                if let id = selectedDock { store.duplicateDock(id); selectStoreDock() }
            } label: {
                Image(systemName: "plus.square.on.square")
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(selectedDock == nil)
            .help("Duplikovať dock")

            Button {
                confirmDeleteDockID = selectedDock
            } label: {
                Image(systemName: "minus")
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(selectedDock == nil)
            .help("Odstrániť dock")

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch router.page {
        case .dock(let id)?:
            if store.dock(id) != nil {
                DockDetailView(dockID: id)
                    .id(id)
            } else {
                placeholder
            }
        case .themes?:
            ThemesPage()
        case .shortcuts?:
            ShortcutsPage()
        case .general?:
            GeneralPage()
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        ContentUnavailableView {
            Label("Vyber dock", systemImage: "dock.rectangle")
        } description: {
            Text("Vľavo vyber dock, ktorý chceš upraviť, alebo pridaj nový.")
        } actions: {
            Button("Pridať dock") {
                store.addDock(edge: .right)
                selectStoreDock()
            }
        }
    }

    // MARK: Actions

    private func ensurePage() {
        switch router.page {
        case .dock(let id)?:
            if store.dock(id) != nil { return }
        case .some:
            return
        case nil:
            break
        }
        if let id = store.selectedDockID ?? store.config.docks.first?.id, store.dock(id) != nil {
            router.page = .dock(id)
        } else {
            router.page = .general
        }
    }

    private func selectStoreDock() {
        if let id = store.selectedDockID { router.page = .dock(id) }
    }

    private func delete(_ id: UUID) {
        store.removeDock(id)
        if let next = store.selectedDockID { router.page = .dock(next) } else { router.page = .general }
    }
}

// MARK: - Sidebar row

@MainActor
private struct DockSidebarRow: View {
    let dock: DockConfig

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: dock.edge.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(dock.appearance.accent))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(dock.name.isEmpty ? "Bez názvu" : dock.name)
                    .lineLimit(1)
                Text("\(dock.edge.displayName) · \(SK.plural(dock.categories.count, "kategória", "kategórie", "kategórií"))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .opacity(dock.isEnabled ? 1 : 0.5)
            Spacer(minLength: 4)
            Toggle("", isOn: DoxStore.shared.binding(dock: dock.id, \.isEnabled))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(dock.isEnabled ? "Vypnúť dock" : "Zapnúť dock")
        }
        .padding(.vertical, 2)
    }
}
