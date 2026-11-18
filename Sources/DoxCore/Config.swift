import Foundation

// MARK: - Themes

/// A named appearance preset. Built-in ones ship with the app; users can save their own.
public struct ThemePreset: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var appearance: DockAppearance
    public var isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, appearance: DockAppearance, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.appearance = appearance
        self.isBuiltIn = isBuiltIn
    }

    /// Applies the preset's look to an appearance while keeping layout-related sizing the user chose.
    public func apply(to current: DockAppearance, keepSizing: Bool) -> DockAppearance {
        var a = appearance
        if keepSizing {
            a.iconSize = current.iconSize
            a.iconSpacing = current.iconSpacing
            a.padding = current.padding
            a.magnification = current.magnification
            a.magnificationSpread = current.magnificationSpread
            a.labelMode = current.labelMode
            a.labelFontSize = current.labelFontSize
        }
        return a
    }
}

public enum BuiltInThemes {
    // Stable ids so a dock can remember which preset it came from.
    private static func uuid(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012ld", n))! }

    public static let all: [ThemePreset] = [obsidian, frost, aurora, graphite, ember, paper, midnight]

    public static var obsidian: ThemePreset {
        var a = DockAppearance()
        a.mode = .dark; a.material = .hud
        a.tint = RGBAColor(hex: "#14141A")!; a.tintOpacity = 0.55
        a.accent = RGBAColor(hex: "#7C8CFF")!
        a.borderColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.14); a.borderWidth = 0.5
        a.cornerRadius = 22; a.shadowRadius = 28; a.shadowOpacity = 0.45
        return ThemePreset(id: uuid(1), name: "Obsidián", appearance: a, isBuiltIn: true)
    }

    public static var frost: ThemePreset {
        var a = DockAppearance()
        a.mode = .light; a.material = .ultraThin
        a.tint = RGBAColor(hex: "#FFFFFF")!; a.tintOpacity = 0.25
        a.accent = RGBAColor(hex: "#0A84FF")!
        a.borderColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.6); a.borderWidth = 1
        a.cornerRadius = 26; a.shadowRadius = 30; a.shadowOpacity = 0.18
        a.categoryHeaderStyle = .divider
        return ThemePreset(id: uuid(2), name: "Mráz", appearance: a, isBuiltIn: true)
    }

    public static var aurora: ThemePreset {
        var a = DockAppearance()
        a.mode = .dark; a.material = .thin
        a.tint = RGBAColor(hex: "#3A1C71")!; a.gradientEnd = RGBAColor(hex: "#0F6B6B")!
        a.tintOpacity = 0.6
        a.accent = RGBAColor(hex: "#5EF2C2")!
        a.borderColor = RGBAColor(hex: "#5EF2C2")!.withAlpha(0.35); a.borderWidth = 1
        a.cornerRadius = 24; a.shadowRadius = 34; a.shadowOpacity = 0.5
        a.runningIndicator = .glow; a.hoverEffect = .magnify
        return ThemePreset(id: uuid(3), name: "Polárna žiara", appearance: a, isBuiltIn: true)
    }

    public static var graphite: ThemePreset {
        var a = DockAppearance()
        a.mode = .system; a.material = .sidebar
        a.tint = RGBAColor(hex: "#2B2B2E")!; a.tintOpacity = 0.15
        a.accent = RGBAColor(hex: "#A0A0A8")!
        a.cornerRadius = 14; a.shadowRadius = 16; a.shadowOpacity = 0.25
        a.hoverEffect = .lift; a.runningIndicator = .bar; a.categoryHeaderStyle = .divider
        return ThemePreset(id: uuid(4), name: "Grafit", appearance: a, isBuiltIn: true)
    }

    public static var ember: ThemePreset {
        var a = DockAppearance()
        a.mode = .dark; a.material = .ultraThick
        a.tint = RGBAColor(hex: "#2A0E0A")!; a.gradientEnd = RGBAColor(hex: "#5C1F0C")!
        a.tintOpacity = 0.65
        a.accent = RGBAColor(hex: "#FF9F45")!
        a.borderColor = RGBAColor(hex: "#FF9F45")!.withAlpha(0.3); a.borderWidth = 1
        a.cornerRadius = 20; a.shadowRadius = 30; a.shadowOpacity = 0.5
        a.hoverEffect = .glow; a.runningIndicator = .glow
        return ThemePreset(id: uuid(5), name: "Žeravé uhlíky", appearance: a, isBuiltIn: true)
    }

    public static var paper: ThemePreset {
        var a = DockAppearance()
        a.mode = .light; a.material = .solid
        a.tint = RGBAColor(hex: "#F6F3EE")!; a.tintOpacity = 1
        a.accent = RGBAColor(hex: "#C2410C")!
        a.borderColor = RGBAColor(hex: "#000000")!.withAlpha(0.08); a.borderWidth = 1
        a.cornerRadius = 18; a.shadowRadius = 20; a.shadowOpacity = 0.12
        a.iconShape = .squircle; a.hoverEffect = .lift; a.categoryHeaderStyle = .label
        return ThemePreset(id: uuid(6), name: "Papier", appearance: a, isBuiltIn: true)
    }

    public static var midnight: ThemePreset {
        var a = DockAppearance()
        a.mode = .dark; a.material = .clear
        a.tint = RGBAColor(hex: "#05060A")!; a.tintOpacity = 0.85
        a.accent = RGBAColor(hex: "#FF4FD8")!
        a.borderColor = RGBAColor(hex: "#FF4FD8")!.withAlpha(0.5); a.borderWidth = 1.5
        a.cornerRadius = 30; a.shadowRadius = 40; a.shadowOpacity = 0.6
        a.iconShape = .circle; a.hoverEffect = .glow; a.runningIndicator = .glow
        return ThemePreset(id: uuid(7), name: "Polnočný neón", appearance: a, isBuiltIn: true)
    }
}

// MARK: - App config

public struct AppConfig: Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var docks: [DockConfig]
    public var customThemes: [ThemePreset]
    public var launchAtLogin: Bool
    public var showMenuBarIcon: Bool
    /// Shows/hides every dock at once.
    public var toggleAllShortcut: KeyShortcut?
    /// Opens the settings window.
    public var settingsShortcut: KeyShortcut?

    public init(version: Int = AppConfig.currentVersion,
                docks: [DockConfig] = [],
                customThemes: [ThemePreset] = [],
                launchAtLogin: Bool = false,
                showMenuBarIcon: Bool = true,
                toggleAllShortcut: KeyShortcut? = nil,
                settingsShortcut: KeyShortcut? = nil) {
        self.version = version
        self.docks = docks
        self.customThemes = customThemes
        self.launchAtLogin = launchAtLogin
        self.showMenuBarIcon = showMenuBarIcon
        self.toggleAllShortcut = toggleAllShortcut
        self.settingsShortcut = settingsShortcut
    }

    public var allThemes: [ThemePreset] { BuiltInThemes.all + customThemes }

    enum CodingKeys: String, CodingKey {
        case version, docks, customThemes, launchAtLogin, showMenuBarIcon, toggleAllShortcut, settingsShortcut
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.decode(.version, default: AppConfig.currentVersion)
        docks = c.decode(.docks, default: [])
        customThemes = c.decode(.customThemes, default: [])
        launchAtLogin = c.decode(.launchAtLogin, default: false)
        showMenuBarIcon = c.decode(.showMenuBarIcon, default: true)
        toggleAllShortcut = c.decode(.toggleAllShortcut, default: nil)
        settingsShortcut = c.decode(.settingsShortcut, default: nil)
    }

    /// First-launch configuration: one dock on the left with a few starter categories.
    public static func starter(homeDirectory: String = NSHomeDirectory()) -> AppConfig {
        let home = homeDirectory
        let work = DockCategory(name: "Práca", symbol: "briefcase.fill", color: RGBAColor(hex: "#7C8CFF")!, items: [
            DockItem(kind: .app(path: "/System/Applications/Mail.app", bundleID: "com.apple.mail")),
            DockItem(kind: .app(path: "/System/Applications/Calendar.app", bundleID: "com.apple.iCal")),
            DockItem(kind: .app(path: "/System/Applications/Notes.app", bundleID: "com.apple.Notes")),
        ])
        let files = DockCategory(name: "Súbory", symbol: "folder.fill", color: RGBAColor(hex: "#F5B544")!, items: [
            DockItem(kind: .folder(path: home + "/Downloads"), folderPresentation: .fan, folderSort: .dateAdded),
            DockItem(kind: .folder(path: home + "/Documents")),
            DockItem(kind: .folder(path: home + "/Desktop")),
        ])
        let web = DockCategory(name: "Web", symbol: "globe", color: RGBAColor(hex: "#5EF2C2")!, items: [
            DockItem(kind: .app(path: "/Applications/Safari.app", bundleID: "com.apple.Safari")),
            DockItem(kind: .link(url: "https://github.com"), customSymbol: "chevron.left.forwardslash.chevron.right"),
        ])
        let tools = DockCategory(name: "Nástroje", symbol: "wrench.and.screwdriver.fill",
                                 color: RGBAColor(hex: "#FF7A90")!, display: .stack, items: [
            DockItem(kind: .app(path: "/System/Applications/Utilities/Terminal.app", bundleID: "com.apple.Terminal")),
            DockItem(kind: .app(path: "/System/Applications/Utilities/Activity Monitor.app", bundleID: "com.apple.ActivityMonitor")),
            DockItem(kind: .app(path: "/System/Applications/System Settings.app", bundleID: "com.apple.systempreferences")),
        ])
        let dock = DockConfig(name: "Hlavný dock", edge: .left,
                              appearance: BuiltInThemes.obsidian.appearance,
                              categories: [work, files, web, tools])
        return AppConfig(docks: [dock])
    }
}
