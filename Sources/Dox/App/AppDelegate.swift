import AppKit
import DoxCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Snapshot of every registered shortcut; hot keys are re-registered only when it changes.
    private struct ShortcutSignature: Equatable {
        struct DockShortcut: Equatable {
            let id: UUID
            let shortcut: KeyShortcut
        }
        var toggleAll: KeyShortcut?
        var settings: KeyShortcut?
        var docks: [DockShortcut]

        init(_ config: AppConfig) {
            toggleAll = config.toggleAllShortcut
            settings = config.settingsShortcut
            docks = config.docks.compactMap { dock in
                guard dock.isEnabled, let s = dock.shortcut else { return nil }
                return DockShortcut(id: dock.id, shortcut: s)
            }
        }
    }

    private var isFirstLaunch = false
    private var shortcutSignature: ShortcutSignature?
    private var launchAtLogin: Bool?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Must run before anything saves the config.
        isFirstLaunch = !FileManager.default.fileExists(atPath: ConfigStore.defaultLocation().path)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let store = DoxStore.shared
        _ = RunningAppsMonitor.shared
        DockManager.shared.start()

        apply(store.config)
        store.onChange.append { [weak self] config in
            self?.apply(config)
        }

        if isFirstLaunch {
            store.saveNow()
            SettingsWindowController.shared.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyCenter.shared.unregisterAll()
        DoxStore.shared.saveNow()
    }

    // MARK: Config side effects

    private func apply(_ config: AppConfig) {
        let signature = ShortcutSignature(config)
        if signature != shortcutSignature {
            shortcutSignature = signature
            registerHotkeys(signature)
        }

        if config.launchAtLogin != launchAtLogin {
            let previous = launchAtLogin
            launchAtLogin = config.launchAtLogin
            // On launch only touch the system when it disagrees with the config.
            if previous != nil || LoginItem.isEnabled != config.launchAtLogin {
                LoginItem.setEnabled(config.launchAtLogin)
            }
        }
    }

    private func registerHotkeys(_ signature: ShortcutSignature) {
        let hotkeys = HotkeyCenter.shared
        hotkeys.unregisterAll()
        if let s = signature.toggleAll {
            hotkeys.register(s, id: "toggleAll") { DoxStore.shared.toggleAllDocks() }
        }
        if let s = signature.settings {
            hotkeys.register(s, id: "settings") { SettingsWindowController.shared.show() }
        }
        for entry in signature.docks {
            let dockID = entry.id
            hotkeys.register(entry.shortcut, id: "dock-\(dockID.uuidString)") {
                DockManager.shared.toggle(dockID: dockID)
            }
        }
    }
}
