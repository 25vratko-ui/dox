import SwiftUI
import AppKit
import DoxCore

/// Gallery of built-in and custom themes with apply / import / export / delete.
@MainActor
struct ThemesPage: View {
    @State private var selectedID: UUID?
    @State private var alert: SettingsAlert?
    @State private var confirmDeleteID: UUID?

    private var store: DoxStore { DoxStore.shared }

    private var selected: ThemePreset? {
        store.config.allThemes.first { $0.id == selectedID }
    }

    var body: some View {
        SettingsScrollPage {
            SettingsPageHeader(title: "Témy",
                               subtitle: "Ucelené vzhľady pre docky. Ulož si vlastné, zdieľaj ich ako JSON.",
                               symbol: "paintpalette.fill")

            actionBar

            SettingsSection("Vstavané", symbol: "sparkles") {
                grid(store.config.allThemes.filter(\.isBuiltIn))
            }

            SettingsSection("Moje témy", symbol: "person.crop.square.fill") {
                let custom = store.config.customThemes
                if custom.isEmpty {
                    HStack(spacing: DS.Spacing.m) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(DS.Color.accent)
                        SettingsCaption("Zatiaľ žiadne. V záložke Vzhľad docku použi „Uložiť ako tému…“ alebo tému importuj zo súboru.")
                    }
                    .padding(.vertical, DS.Spacing.s)
                } else {
                    grid(custom)
                }
            }
        }
        .alert(item: $alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog("Odstrániť tému?",
                            isPresented: Binding(get: { confirmDeleteID != nil },
                                                 set: { if !$0 { confirmDeleteID = nil } }),
                            titleVisibility: .visible) {
            Button("Odstrániť", role: .destructive) {
                if let id = confirmDeleteID {
                    store.deleteTheme(id)
                    if selectedID == id { selectedID = nil }
                }
                confirmDeleteID = nil
            }
            Button("Zrušiť", role: .cancel) { confirmDeleteID = nil }
        } message: {
            Text("Docky, ktoré ju používajú, si svoj vzhľad ponechajú.")
        }
    }

    // MARK: Pieces

    private var actionBar: some View {
        HStack(spacing: DS.Spacing.s) {
            Menu {
                ForEach(store.config.docks) { dock in
                    Button(dock.name) { if let t = selected { apply(t, to: dock.id) } }
                }
                if store.config.docks.count > 1 {
                    Divider()
                    Button("Všetky docky") {
                        if let t = selected { for d in store.config.docks { apply(t, to: d.id) } }
                    }
                }
            } label: {
                Label("Použiť na dock", systemImage: "wand.and.stars")
            }
            .fixedSize()
            .disabled(selected == nil || store.config.docks.isEmpty)

            Button {
                if let t = selected { export(t) }
            } label: {
                Label("Exportovať…", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SoftButtonStyle())
            .disabled(selected == nil)

            Button(action: importTheme) {
                Label("Importovať…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(SoftButtonStyle())

            Spacer()

            if let t = selected, !t.isBuiltIn {
                Button {
                    confirmDeleteID = t.id
                } label: {
                    Label("Odstrániť", systemImage: "trash")
                }
                .buttonStyle(SoftButtonStyle(destructive: true))
            }
        }
    }

    private func grid(_ themes: [ThemePreset]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 180), spacing: DS.Spacing.l)],
                  alignment: .leading, spacing: DS.Spacing.l) {
            ForEach(themes) { theme in
                ThemeCard(theme: theme, isSelected: theme.id == selectedID)
                    .onTapGesture { withAnimation(DS.Motion.snappy) { selectedID = theme.id } }
                    .overlay(alignment: .topTrailing) {
                        if !theme.isBuiltIn {
                            Button {
                                confirmDeleteID = theme.id
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.white, Color.black.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                            .help("Odstrániť tému")
                        }
                    }
                    .contextMenu {
                        Menu("Použiť na dock") {
                            ForEach(store.config.docks) { dock in
                                Button(dock.name) { apply(theme, to: dock.id) }
                            }
                        }
                        Button("Exportovať…") { export(theme) }
                        if !theme.isBuiltIn {
                            Divider()
                            Button("Odstrániť…", role: .destructive) { confirmDeleteID = theme.id }
                        }
                    }
            }
        }
    }

    // MARK: Actions

    private func apply(_ theme: ThemePreset, to dockID: UUID) {
        store.updateDock(dockID) { $0.appearance = theme.apply(to: $0.appearance, keepSizing: true) }
    }

    private func export(_ theme: ThemePreset) {
        do {
            let data = try ConfigStore.exportTheme(theme)
            let safeName = theme.name.replacingOccurrences(of: "/", with: "-")
            _ = try JSONFilePanel.save(data, suggestedName: "\(safeName).json",
                                       message: "Exportovať tému „\(theme.name)“")
        } catch {
            alert = SettingsAlert(title: "Export zlyhal", message: error.localizedDescription)
        }
    }

    private func importTheme() {
        do {
            guard let data = try JSONFilePanel.open(message: "Vyber súbor s témou Dox (.json)") else { return }
            let theme = try ConfigStore.importTheme(from: data)
            store.update { $0.customThemes.append(theme) }
            selectedID = theme.id
        } catch {
            alert = SettingsAlert(title: "Import zlyhal",
                                  message: "Súbor nie je platná téma Dox.\n\(error.localizedDescription)")
        }
    }
}
