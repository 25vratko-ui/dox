import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DoxCore

/// Turns drops (files / apps / URLs from Finder or a browser, or dragged dock tiles)
/// into store mutations.
@MainActor
enum DockDropHandler {
    /// File URLs and web URLs from other apps; plain text carries a dragged tile's UUID.
    static let acceptedTypes: [UTType] = [.fileURL, .url, .plainText]

    /// Handles a drop onto a category.
    /// - Parameters:
    ///   - categoryID: target category; `nil` creates/uses the first visible category.
    ///   - index: insertion index inside the category; `nil` appends.
    /// - Returns: `true` when at least one provider is usable.
    @discardableResult
    static func handle(_ providers: [NSItemProvider], dockID: UUID, categoryID: UUID?, index: Int?) -> Bool {
        let usable = providers.filter(canHandle)
        guard !usable.isEmpty else { return false }
        guard let targetID = categoryID ?? ensureCategory(in: dockID) else { return false }

        for (offset, provider) in usable.enumerated() {
            let insertAt = index.map { $0 + offset }
            load(provider, dockID: dockID, categoryID: targetID, index: insertAt)
        }
        return true
    }

    /// Builds the right dock item for a file / app / folder / web URL.
    static func item(for url: URL) -> DockItem {
        guard url.isFileURL else { return DockItem.inferred(from: url, isDirectory: false) }
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        let bundleID = url.pathExtension.lowercased() == "app" ? Bundle(url: url)?.bundleIdentifier : nil
        return DockItem.inferred(from: url, isDirectory: isDirectory, bundleID: bundleID)
    }

    /// Adds dropped items when a dock has no category yet.
    static func ensureCategory(in dockID: UUID) -> UUID? {
        guard let dock = DoxStore.shared.dock(dockID) else { return nil }
        if let first = dock.visibleCategories.first { return first.id }
        let category = DockCategory(name: "Obľúbené", symbol: "star.fill")
        DoxStore.shared.updateDock(dockID) { $0.addCategory(category) }
        return category.id
    }

    // MARK: Private

    /// Loads a provider's payload. `nonisolated` so the completion closures are not inferred as
    /// main-actor isolated (NSItemProvider calls them on a background queue).
    nonisolated private static func load(_ provider: NSItemProvider, dockID: UUID, categoryID: UUID, index: Int?) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    insert(url: url, dockID: dockID, categoryID: categoryID, index: index)
                }
            }
        } else {
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                guard let text else { return }
                Task { @MainActor in
                    insert(text: text, dockID: dockID, categoryID: categoryID, index: index)
                }
            }
        }
    }

    private static func canHandle(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
    }

    private static func insert(url: URL, dockID: UUID, categoryID: UUID, index: Int?) {
        let newItem = item(for: url)
        DoxStore.shared.updateDock(dockID) { $0.addItem(newItem, to: categoryID, at: index) }
    }

    /// Plain text is either a dragged tile (UUID) or a URL typed/dragged as text.
    private static func insert(text: String, dockID: UUID, categoryID: UUID, index: Int?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let store = DoxStore.shared

        if let itemID = UUID(uuidString: trimmed) {
            // Same dock → reorder / move between categories.
            if store.dock(dockID)?.item(itemID) != nil {
                store.updateDock(dockID) { d in
                    let count = d.categories.first { $0.id == categoryID }?.items.count ?? 0
                    d.moveItem(itemID, toCategory: categoryID, at: index ?? count)
                }
                return
            }
            // Another dock → move across docks.
            if let source = store.config.docks.first(where: { $0.item(itemID) != nil }),
               let moved = source.item(itemID) {
                store.updateDock(source.id) { $0.removeItem(itemID) }
                store.updateDock(dockID) { $0.addItem(moved, to: categoryID, at: index) }
            }
            return
        }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty,
           url.host != nil || scheme == "mailto" {
            insert(url: url, dockID: dockID, categoryID: categoryID, index: index)
        }
    }
}
