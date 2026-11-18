import AppKit
import DoxCore

/// Opens / reveals dock items.
@MainActor
enum ItemLauncher {
    /// Performs the click action for `item`.
    /// - Parameters:
    ///   - behavior: the owning dock's behavior (`clickAction`, `hideAfterLaunch`).
    ///   - alternate: ⌥-click; flips `clickAction` (open ↔ reveal in Finder).
    static func open(_ item: DockItem, behavior: DockBehavior, alternate: Bool) {
        var action = behavior.clickAction
        if alternate { action = (action == .open) ? .revealInFinder : .open }

        var didSomething = true
        switch item.kind {
        case .app(let path, let bundleID):
            if action == .revealInFinder {
                didSomething = reveal(path: path, bundleID: bundleID)
            } else {
                didSomething = launchApp(path: path, bundleID: bundleID)
            }
        case .folder(let path), .file(let path):
            guard FileManager.default.fileExists(atPath: path) else {
                NSSound.beep()
                return
            }
            let url = URL(fileURLWithPath: path)
            if action == .revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                didSomething = NSWorkspace.shared.open(url)
            }
        case .link(let string):
            guard let url = linkURL(string) else {
                NSSound.beep()
                return
            }
            didSomething = NSWorkspace.shared.open(url)
        case .separator, .spacer:
            return
        }

        guard didSomething else { return }
        if behavior.hideAfterLaunch, let dockID = owningDockID(of: item.id) {
            DockManager.shared.hide(dockID: dockID)
        }
    }

    /// Opens an arbitrary file URL (used by folder stacks).
    static func open(url: URL) {
        if !NSWorkspace.shared.open(url) { NSSound.beep() }
    }

    /// Shows the item in Finder (apps, files, folders). Links are ignored.
    static func revealInFinder(_ item: DockItem) {
        switch item.kind {
        case .app(let path, let bundleID):
            _ = reveal(path: path, bundleID: bundleID)
        case .folder(let path), .file(let path):
            _ = reveal(path: path, bundleID: nil)
        default:
            NSSound.beep()
        }
    }

    /// Shows a file URL in Finder (used by folder stacks).
    static func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: Private

    private static func appURL(path: String, bundleID: String?) -> URL? {
        if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        if let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) { return url }
        return nil
    }

    private static func launchApp(path: String, bundleID: String?) -> Bool {
        guard let url = appURL(path: path, bundleID: bundleID) else {
            NSSound.beep()
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error { NSLog("Dox: failed to open \(url.path): \(error)") }
        }
        return true
    }

    private static func reveal(path: String, bundleID: String?) -> Bool {
        let url: URL?
        if bundleID != nil { url = appURL(path: path, bundleID: bundleID) }
        else { url = FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil }
        guard let url else {
            NSSound.beep()
            return false
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }

    /// Accepts full URLs (any scheme) and bare hosts like "github.com".
    private static func linkURL(_ raw: String) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let url = URL(string: s), let scheme = url.scheme, !scheme.isEmpty { return url }
        return URL(string: "https://" + s)
    }

    private static func owningDockID(of itemID: UUID) -> UUID? {
        DoxStore.shared.config.docks.first { $0.item(itemID) != nil }?.id
    }
}
