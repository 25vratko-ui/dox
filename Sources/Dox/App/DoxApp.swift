import SwiftUI
import AppKit
import DoxCore

@main
struct DoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        let store = DoxStore.shared
        let showIcon = store.config.showMenuBarIcon
        MenuBarExtra("Dox",
                     systemImage: "square.stack.3d.up.fill",
                     isInserted: Binding(
                        get: { showIcon },
                        set: { newValue in store.update { $0.showMenuBarIcon = newValue } }
                     )) {
            DoxMenuContent()
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Menu of the menu bar item.
private struct DoxMenuContent: View {
    var body: some View {
        let store = DoxStore.shared
        let manager = DockManager.shared

        ForEach(store.config.docks) { dock in
            let shown = manager.isDockShown(dock.id)
            Toggle(dock.name.isEmpty ? "Dock" : dock.name, isOn: Binding(
                get: { shown },
                set: { manager.setDockShown(dock.id, $0) }
            ))
        }
        if !store.config.docks.isEmpty {
            Divider()
        }
        Button("Zobraziť/skryť všetky") {
            store.toggleAllDocks()
        }
        Button("Nastavenia…") {
            SettingsWindowController.shared.show()
        }
        .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Ukončiť Dox") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
