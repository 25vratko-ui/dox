import AppKit
import SwiftUI

/// Owns the settings window. While it is open the app temporarily becomes a regular app
/// (Dock icon, Cmd-Tab, main menu) and returns to `.accessory` when it closes.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 740),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.title = "Nastavenia Dox"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = NSToolbar(identifier: "DoxSettingsToolbar")
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.contentMinSize = NSSize(width: 920, height: 640)
        window.minSize = NSSize(width: 920, height: 640)

        let hosting = NSHostingView(rootView: SettingsRootView())
        hosting.sceneBridgingOptions = [.toolbars, .title]
        window.contentView = hosting

        window.center()
        window.setFrameAutosaveName("DoxSettingsWindow")
        window.delegate = self
        return window
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
