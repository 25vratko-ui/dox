import Foundation

/// Address of an item inside a dock.
public struct ItemLocation: Hashable, Sendable {
    public var categoryID: UUID
    public var itemID: UUID
    public init(categoryID: UUID, itemID: UUID) {
        self.categoryID = categoryID
        self.itemID = itemID
    }
}

/// Pure, testable mutations on a dock. The UI layer calls these and then persists the config.
extension DockConfig {
    public func categoryIndex(_ id: UUID) -> Int? { categories.firstIndex { $0.id == id } }

    public func location(ofItem itemID: UUID) -> ItemLocation? {
        for c in categories where c.items.contains(where: { $0.id == itemID }) {
            return ItemLocation(categoryID: c.id, itemID: itemID)
        }
        return nil
    }

    public func item(_ itemID: UUID) -> DockItem? {
        for c in categories { if let i = c.items.first(where: { $0.id == itemID }) { return i } }
        return nil
    }

    @discardableResult
    public mutating func addCategory(_ category: DockCategory, at index: Int? = nil) -> UUID {
        let i = (index ?? categories.count).clamped(to: 0...categories.count)
        categories.insert(category, at: i)
        return category.id
    }

    public mutating func removeCategory(_ id: UUID) {
        categories.removeAll { $0.id == id }
    }

    public mutating func moveCategory(_ id: UUID, to newIndex: Int) {
        guard let from = categoryIndex(id) else { return }
        let c = categories.remove(at: from)
        categories.insert(c, at: newIndex.clamped(to: 0...categories.count))
    }

    /// Adds an item to a category. Duplicates (same path / url) inside the same category are ignored.
    /// - Returns: `true` when the item was inserted.
    @discardableResult
    public mutating func addItem(_ item: DockItem, to categoryID: UUID, at index: Int? = nil) -> Bool {
        guard let ci = categoryIndex(categoryID) else { return false }
        if !item.kind.isDecorative,
           categories[ci].items.contains(where: { $0.kind.identityKey == item.kind.identityKey }) {
            return false
        }
        let items = categories[ci].items
        let i = (index ?? items.count).clamped(to: 0...items.count)
        categories[ci].items.insert(item, at: i)
        return true
    }

    public mutating func removeItem(_ itemID: UUID) {
        for i in categories.indices { categories[i].items.removeAll { $0.id == itemID } }
    }

    /// Moves an item within or across categories.
    public mutating func moveItem(_ itemID: UUID, toCategory targetID: UUID, at index: Int) {
        guard let source = location(ofItem: itemID),
              let si = categoryIndex(source.categoryID),
              let ti = categoryIndex(targetID),
              let from = categories[si].items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = categories[si].items.remove(at: from)
        var dest = index
        // Removing from the same array before the insertion point shifts indices left.
        if si == ti && from < index { dest -= 1 }
        dest = dest.clamped(to: 0...categories[ti].items.count)
        categories[ti].items.insert(item, at: dest)
    }

    public mutating func updateItem(_ item: DockItem) {
        for ci in categories.indices {
            if let ii = categories[ci].items.firstIndex(where: { $0.id == item.id }) {
                categories[ci].items[ii] = item
                return
            }
        }
    }

    /// Returns a deep copy with fresh ids (for "Duplicate dock").
    public func duplicated(name: String? = nil) -> DockConfig {
        var copy = self
        copy.id = UUID()
        copy.name = name ?? "\(self.name) – kópia"
        copy.shortcut = nil
        copy.categories = categories.map { c in
            var nc = c
            nc.id = UUID()
            nc.items = c.items.map { var ni = $0; ni.id = UUID(); return ni }
            return nc
        }
        return copy
    }

    /// Filters items by a search query (title, path or url, case and diacritic insensitive).
    public func search(_ query: String) -> [DockItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return categories.flatMap(\.items).filter { item in
            guard !item.kind.isDecorative else { return false }
            let haystack = [item.displayTitle, item.kind.path ?? "", item.kind.linkURL ?? ""]
            return haystack.contains { $0.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }
}

extension DockItemKind {
    /// Used for duplicate detection: two items pointing at the same thing.
    public var identityKey: String {
        switch self {
        case .app(let path, let bundleID): "app:" + (bundleID ?? path)
        case .folder(let path): "folder:" + path
        case .file(let path): "file:" + path
        case .link(let url): "link:" + url
        case .separator: "separator"
        case .spacer: "spacer"
        }
    }

    public var linkURL: String? {
        if case .link(let url) = self { return url }
        return nil
    }
}

extension AppConfig {
    public func dockIndex(_ id: UUID) -> Int? { docks.firstIndex { $0.id == id } }

    /// Every shortcut in use, used to warn about conflicts while recording a new one.
    public func shortcutConflicts(for shortcut: KeyShortcut, excludingDock dockID: UUID? = nil) -> [String] {
        var names: [String] = []
        if toggleAllShortcut?.matches(shortcut) == true { names.append("Zobraziť/skryť všetky docky") }
        if settingsShortcut?.matches(shortcut) == true { names.append("Nastavenia") }
        for d in docks where d.id != dockID && d.shortcut?.matches(shortcut) == true { names.append(d.name) }
        return names
    }
}
