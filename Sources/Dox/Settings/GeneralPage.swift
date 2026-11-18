import SwiftUI
import AppKit
import DoxCore

/// App-wide settings: login item, menu bar icon, config import / export, reset.
@MainActor
struct GeneralPage: View {
    @State private var confirmReset = false
    @State private var pendingImport: AppConfig?
    @State private var alert: SettingsAlert?

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        SettingsScrollPage {
            SettingsPageHeader(title: "Všeobecné",
                               subtitle: "Spúšťanie, ikona v lište a záloha celej konfigurácie.",
                               symbol: "gearshape.fill")

            SettingsSection("Spúšťanie", symbol: "power") {
                ToggleRow("Spustiť pri prihlásení",
                          subtitle: "Dox sa spustí automaticky po prihlásení do Macu.",
                          isOn: store.binding(\.launchAtLogin))
                if store.config.launchAtLogin != LoginItem.isEnabled {
                    SettingsCaption("Systém zatiaľ zmenu nepotvrdil. Ak treba, povoľ Dox v Nastaveniach systému › Všeobecné › Položky prihlásenia.",
                                    symbol: "exclamationmark.triangle.fill")
                }
                ToggleRow("Ikona v lište ponúk",
                          subtitle: "Rýchly prístup k dockom a nastaveniam.",
                          isOn: store.binding(\.showMenuBarIcon))
                if !store.config.showMenuBarIcon {
                    SettingsCaption("Bez ikony otvoríš nastavenia skratkou alebo opätovným spustením aplikácie Dox.",
                                    symbol: "info.circle")
                }
            }

            SettingsSection("Docky", symbol: "dock.rectangle") {
                HStack(spacing: DS.Spacing.s) {
                    Text(SK.plural(store.config.docks.count, "dock", "docky", "dockov"))
                        .font(DS.Font.rowTitle)
                    Text("· \(SK.plural(store.config.customThemes.count, "vlastná téma", "vlastné témy", "vlastných tém"))")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryText)
                    Spacer()
                    Button {
                        store.toggleAllDocks()
                    } label: {
                        Label("Zobraziť/skryť všetky", systemImage: "eye")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }

            SettingsSection("Záloha konfigurácie", symbol: "externaldrive.fill") {
                SettingsCaption("Exportuj všetky docky, kategórie, témy a skratky do jedného súboru JSON – napríklad na prenos do iného Macu.")
                HStack(spacing: DS.Spacing.s) {
                    Button(action: exportConfig) {
                        Label("Exportovať…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SoftButtonStyle())
                    Button(action: importConfig) {
                        Label("Importovať…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SoftButtonStyle())
                    Spacer()
                }
            }

            SettingsSection("Obnovenie", symbol: "arrow.counterclockwise") {
                HStack(spacing: DS.Spacing.m) {
                    SettingsCaption("Vráti úvodnú konfiguráciu s jedným dockom. Vlastné docky, témy a skratky sa stratia.")
                    Spacer()
                    Button {
                        confirmReset = true
                    } label: {
                        Label("Obnoviť predvolené", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SoftButtonStyle(destructive: true))
                }
            }

            HStack(spacing: DS.Spacing.s) {
                Spacer()
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(DS.Color.accent)
                Text("Dox \(appVersion)")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondaryText)
                Spacer()
            }
            .padding(.top, DS.Spacing.s)
        }
        .confirmationDialog("Obnoviť predvolené nastavenia?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Obnoviť", role: .destructive) {
                store.replaceConfig(AppConfig.starter())
                SettingsRouter.shared.page = .general
            }
            Button("Zrušiť", role: .cancel) {}
        } message: {
            Text("Túto akciu nie je možné vrátiť. Tip: najprv si konfiguráciu exportuj.")
        }
        .confirmationDialog("Nahradiť konfiguráciu?",
                            isPresented: Binding(get: { pendingImport != nil },
                                                 set: { if !$0 { pendingImport = nil } }),
                            titleVisibility: .visible) {
            Button("Nahradiť", role: .destructive) {
                if let config = pendingImport {
                    store.replaceConfig(config)
                    SettingsRouter.shared.page = .general
                }
                pendingImport = nil
            }
            Button("Zrušiť", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Importovaná konfigurácia (\(SK.plural(pendingImport?.docks.count ?? 0, "dock", "docky", "dockov"))) nahradí tú súčasnú.")
        }
        .alert(item: $alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func exportConfig() {
        do {
            let data = try ConfigStore.exportData(store.config)
            _ = try JSONFilePanel.save(data, suggestedName: "Dox-konfiguracia.json",
                                       message: "Exportovať celú konfiguráciu Dox")
        } catch {
            alert = SettingsAlert(title: "Export zlyhal", message: error.localizedDescription)
        }
    }

    private func importConfig() {
        do {
            guard let data = try JSONFilePanel.open(message: "Vyber súbor s konfiguráciou Dox (.json)") else { return }
            pendingImport = try ConfigStore.importConfig(from: data)
        } catch {
            alert = SettingsAlert(title: "Import zlyhal",
                                  message: "Súbor nie je platná konfigurácia Dox.\n\(error.localizedDescription)")
        }
    }
}
