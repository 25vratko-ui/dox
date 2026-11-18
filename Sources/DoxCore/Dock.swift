import Foundation

// MARK: - Items

public enum DockItemKind: Codable, Hashable, Sendable {
    /// An application bundle. `bundleID` is used to detect running state and survives app moves.
    case app(path: String, bundleID: String?)
    /// A folder; clicking opens a stack popover with its contents.
    case folder(path: String)
    /// Any document.
    case file(path: String)
    /// A web link or any URL scheme (mailto:, slack:, ...).
    case link(url: String)
    /// Visual-only separator line.
    case separator
    /// Visual-only flexible gap.
    case spacer

    public var path: String? {
        switch self {
        case .app(let p, _), .folder(let p), .file(let p): p
        default: nil
        }
    }

    public var isDecorative: Bool {
        switch self {
        case .separator, .spacer: true
        default: false
        }
    }

    public var typeName: String {
        switch self {
        case .app: "Aplikácia"
        case .folder: "Priečinok"
        case .file: "Súbor"
        case .link: "Odkaz"
        case .separator: "Oddeľovač"
        case .spacer: "Medzera"
        }
    }
}

/// How a folder item presents its contents.
public enum FolderPresentation: String, Codable, CaseIterable, Sendable, Identifiable {
    case grid, list, fan
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .grid: "Mriežka"
        case .list: "Zoznam"
        case .fan: "Vejár"
        }
    }
}

public enum FolderSort: String, Codable, CaseIterable, Sendable, Identifiable {
    case name, dateModified, dateAdded, kind
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .name: "Názov"
        case .dateModified: "Dátum úpravy"
        case .dateAdded: "Dátum pridania"
        case .kind: "Typ"
        }
    }
}

public struct DockItem: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: DockItemKind
    /// Overrides the label derived from the file/app/link.
    public var customTitle: String?
    /// SF Symbol used instead of the file icon (always used for links if set).
    public var customSymbol: String?
    /// Tint for symbol icons / link tiles.
    public var tint: RGBAColor?
    public var folderPresentation: FolderPresentation
    public var folderSort: FolderSort

    public init(id: UUID = UUID(),
                kind: DockItemKind,
                customTitle: String? = nil,
                customSymbol: String? = nil,
                tint: RGBAColor? = nil,
                folderPresentation: FolderPresentation = .grid,
                folderSort: FolderSort = .name) {
        self.id = id
        self.kind = kind
        self.customTitle = customTitle
        self.customSymbol = customSymbol
        self.tint = tint
        self.folderPresentation = folderPresentation
        self.folderSort = folderSort
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, customTitle, customSymbol, tint, folderPresentation, folderSort
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `kind` is the only truly required field.
        kind = try c.decode(DockItemKind.self, forKey: .kind)
        id = c.decode(.id, default: UUID())
        customTitle = c.decode(.customTitle, default: nil)
        customSymbol = c.decode(.customSymbol, default: nil)
        tint = c.decode(.tint, default: nil)
        folderPresentation = c.decode(.folderPresentation, default: .grid)
        folderSort = c.decode(.folderSort, default: .name)
    }

    /// Label shown in the dock: custom title, else the file name without extension, else the link host.
    public var displayTitle: String {
        if let t = customTitle, !t.trimmingCharacters(in: .whitespaces).isEmpty { return t }
        switch kind {
        case .app(let path, _):
            let last = (path as NSString).lastPathComponent
            return (last as NSString).deletingPathExtension
        case .folder(let path), .file(let path):
            return (path as NSString).lastPathComponent
        case .link(let url):
            if let host = URL(string: url)?.host { return host.replacingOccurrences(of: "www.", with: "") }
            return url
        case .separator: return "Oddeľovač"
        case .spacer: return "Medzera"
        }
    }

    /// Infers the right item kind for a dropped/added URL.
    /// - Parameters:
    ///   - isDirectory: whether the file URL points at a directory (injected for testability).
    ///   - bundleID: bundle identifier when the URL is an app bundle.
    public static func inferred(from url: URL, isDirectory: Bool, bundleID: String? = nil) -> DockItem {
        guard url.isFileURL else { return DockItem(kind: .link(url: url.absoluteString)) }
        let path = url.standardizedFileURL.path
        if url.pathExtension.lowercased() == "app" {
            return DockItem(kind: .app(path: path, bundleID: bundleID))
        }
        return DockItem(kind: isDirectory ? .folder(path: path) : .file(path: path))
    }
}

// MARK: - Categories

public enum CategoryDisplay: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Items appear directly in the dock.
    case inline
    /// The category collapses into a single tile; clicking opens its items in a popover.
    case stack
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .inline: "V docku"
        case .stack: "Zložená do jednej ikony"
        }
    }
}

public struct DockCategory: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public var color: RGBAColor
    public var display: CategoryDisplay
    /// Hidden categories are kept in the config but not shown in the dock.
    public var isHidden: Bool
    public var items: [DockItem]

    public init(id: UUID = UUID(),
                name: String,
                symbol: String = "square.grid.2x2",
                color: RGBAColor = RGBAColor(hex: "#7C8CFF")!,
                display: CategoryDisplay = .inline,
                isHidden: Bool = false,
                items: [DockItem] = []) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.color = color
        self.display = display
        self.isHidden = isHidden
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case id, name, symbol, color, display, isHidden, items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decode(.id, default: UUID())
        name = c.decode(.name, default: "Kategória")
        symbol = c.decode(.symbol, default: "square.grid.2x2")
        color = c.decode(.color, default: RGBAColor(hex: "#7C8CFF")!)
        display = c.decode(.display, default: .inline)
        isHidden = c.decode(.isHidden, default: false)
        // One malformed item must not wipe the whole category.
        items = (try? c.decodeIfPresent(LossyArray<DockItem>.self, forKey: .items))?.elements ?? []
    }
}

// MARK: - Behavior

public enum AutoHideMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Always visible.
    case never
    /// Slides away when the pointer leaves, comes back at the screen edge.
    case auto
    /// Shown only via its keyboard shortcut or the menu bar.
    case manual
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .never: "Vždy viditeľný"
        case .auto: "Automaticky skrývať"
        case .manual: "Iba skratkou"
        }
    }
}

public enum ClickAction: String, Codable, CaseIterable, Sendable, Identifiable {
    case open, revealInFinder
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .open: "Otvoriť"
        case .revealInFinder: "Ukázať vo Finderi"
        }
    }
}

public struct DockBehavior: Codable, Hashable, Sendable {
    public var autoHide: AutoHideMode = .never
    /// Seconds before hiding after the pointer leaves.
    public var hideDelay: Double = 0.6
    /// Seconds the pointer must rest at the edge before revealing.
    public var revealDelay: Double = 0.15
    public var alwaysOnTop: Bool = true
    public var showOnAllSpaces: Bool = true
    public var hideInFullScreen: Bool = true
    public var display: DisplayTarget = .main
    public var alignment: EdgeAlignment = .center
    /// Extra shift along the edge, as a fraction of the screen length (-0.5...0.5).
    public var alignmentOffset: Double = 0
    /// Gap between the dock and the screen edge.
    public var edgeInset: Double = 8
    /// Option-click always does the opposite of `clickAction`.
    public var clickAction: ClickAction = .open
    /// Auto-hide the dock right after something is opened from it.
    public var hideAfterLaunch: Bool = false
    public var showRunningApps: Bool = true

    public init() {}

    enum CodingKeys: String, CodingKey {
        case autoHide, hideDelay, revealDelay, alwaysOnTop, showOnAllSpaces, hideInFullScreen
        case display, alignment, alignmentOffset, edgeInset, clickAction, hideAfterLaunch, showRunningApps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DockBehavior()
        autoHide = c.decode(.autoHide, default: d.autoHide)
        hideDelay = c.decode(.hideDelay, default: d.hideDelay)
        revealDelay = c.decode(.revealDelay, default: d.revealDelay)
        alwaysOnTop = c.decode(.alwaysOnTop, default: d.alwaysOnTop)
        showOnAllSpaces = c.decode(.showOnAllSpaces, default: d.showOnAllSpaces)
        hideInFullScreen = c.decode(.hideInFullScreen, default: d.hideInFullScreen)
        display = c.decode(.display, default: d.display)
        alignment = c.decode(.alignment, default: d.alignment)
        alignmentOffset = c.decode(.alignmentOffset, default: d.alignmentOffset)
        edgeInset = c.decode(.edgeInset, default: d.edgeInset)
        clickAction = c.decode(.clickAction, default: d.clickAction)
        hideAfterLaunch = c.decode(.hideAfterLaunch, default: d.hideAfterLaunch)
        showRunningApps = c.decode(.showRunningApps, default: d.showRunningApps)
    }
}

// MARK: - Layout

public enum DockLayoutStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    /// A single row (or column on vertical edges).
    case line
    /// Multiple rows/columns; `DockConfig.gridLines` sets how many.
    case grid
    /// One line per category, stacked (a "shelf" look).
    case shelves
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .line: "Jeden rad"
        case .grid: "Mriežka"
        case .shelves: "Police podľa kategórií"
        }
    }
}

// MARK: - Dock

public struct DockConfig: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var edge: DockEdge
    public var layout: DockLayoutStyle
    /// Rows (horizontal dock) or columns (vertical dock) used by the `.grid` layout.
    public var gridLines: Int
    public var appearance: DockAppearance
    public var behavior: DockBehavior
    public var categories: [DockCategory]
    /// Toggles this dock's visibility.
    public var shortcut: KeyShortcut?

    public init(id: UUID = UUID(),
                name: String,
                isEnabled: Bool = true,
                edge: DockEdge = .left,
                layout: DockLayoutStyle = .line,
                gridLines: Int = 2,
                appearance: DockAppearance = DockAppearance(),
                behavior: DockBehavior = DockBehavior(),
                categories: [DockCategory] = [],
                shortcut: KeyShortcut? = nil) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.edge = edge
        self.layout = layout
        self.gridLines = gridLines
        self.appearance = appearance
        self.behavior = behavior
        self.categories = categories
        self.shortcut = shortcut
    }

    /// Categories that should be rendered.
    public var visibleCategories: [DockCategory] { categories.filter { !$0.isHidden } }

    /// Total number of tiles rendered (stack categories count as one tile).
    public var visibleTileCount: Int {
        visibleCategories.reduce(0) { $0 + ($1.display == .stack ? 1 : $1.items.count) }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, edge, layout, gridLines, appearance, behavior, categories, shortcut
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decode(.id, default: UUID())
        name = c.decode(.name, default: "Dock")
        isEnabled = c.decode(.isEnabled, default: true)
        edge = c.decode(.edge, default: .left)
        layout = c.decode(.layout, default: .line)
        gridLines = c.decode(.gridLines, default: 2)
        appearance = c.decode(.appearance, default: DockAppearance())
        behavior = c.decode(.behavior, default: DockBehavior())
        categories = (try? c.decodeIfPresent(LossyArray<DockCategory>.self, forKey: .categories))?.elements ?? []
        shortcut = c.decode(.shortcut, default: nil)
    }
}
