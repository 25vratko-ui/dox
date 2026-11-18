import Foundation

/// Backdrop material. Maps to NSVisualEffectView materials in the app layer,
/// plus two non-blur modes (`solid`, `clear`).
public enum DockMaterial: String, Codable, CaseIterable, Sendable, Identifiable {
    case ultraThin, thin, regular, thick, ultraThick, hud, sidebar, menu, popover, solid, clear
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .ultraThin: "Ultra tenké sklo"
        case .thin: "Tenké sklo"
        case .regular: "Sklo"
        case .thick: "Hrubé sklo"
        case .ultraThick: "Ultra hrubé sklo"
        case .hud: "HUD"
        case .sidebar: "Bočný panel"
        case .menu: "Menu"
        case .popover: "Popover"
        case .solid: "Plná farba"
        case .clear: "Priehľadné"
        }
    }
}

public enum AppearanceMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .system: "Podľa systému"
        case .light: "Svetlý"
        case .dark: "Tmavý"
        }
    }
}

public enum LabelMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case never, onHover, always
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .never: "Nikdy"
        case .onHover: "Pri prejdení myšou"
        case .always: "Vždy"
        }
    }
}

public enum HoverEffect: String, Codable, CaseIterable, Sendable, Identifiable {
    case magnify, lift, glow, none
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .magnify: "Zväčšenie"
        case .lift: "Nadvihnutie"
        case .glow: "Žiara"
        case .none: "Žiadny"
        }
    }
}

public enum RunningIndicator: String, Codable, CaseIterable, Sendable, Identifiable {
    case none, dot, bar, glow
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .none: "Skryť"
        case .dot: "Bodka"
        case .bar: "Čiarka"
        case .glow: "Žiara"
        }
    }
}

/// How a category is presented inside the dock.
public enum CategoryHeaderStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Categories are separated only by spacing.
    case hidden
    /// A thin divider line between categories.
    case divider
    /// A small colored capsule with the category symbol.
    case pill
    /// Symbol + name label above/next to the group.
    case label
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .hidden: "Iba medzera"
        case .divider: "Deliaca čiara"
        case .pill: "Farebná kapsula"
        case .label: "Názov kategórie"
        }
    }
}

public enum IconShape: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Original app icon, untouched.
    case original
    /// Icon placed on a rounded-square tile.
    case squircle
    /// Icon placed on a circle tile.
    case circle
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .original: "Pôvodná"
        case .squircle: "Zaoblený štvorec"
        case .circle: "Kruh"
        }
    }
}

/// Every visual parameter of a dock. All numeric values are in points unless noted.
public struct DockAppearance: Codable, Hashable, Sendable {
    public var mode: AppearanceMode = .system
    public var material: DockMaterial = .hud
    /// Color layered over the material.
    public var tint: RGBAColor = RGBAColor(hex: "#1C1C24")!
    /// 0...1 strength of `tint` over the material.
    public var tintOpacity: Double = 0.35
    /// 0...1 overall dock background opacity (material + tint).
    public var backgroundOpacity: Double = 1.0
    /// Optional gradient end color; nil = flat tint.
    public var gradientEnd: RGBAColor? = nil
    public var accent: RGBAColor = RGBAColor(hex: "#7C8CFF")!

    public var iconSize: Double = 48
    public var iconSpacing: Double = 8
    public var iconShape: IconShape = .original
    public var iconShadow: Bool = true
    public var padding: Double = 10
    public var cornerRadius: Double = 22

    public var borderWidth: Double = 0.5
    public var borderColor: RGBAColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.18)
    public var shadowRadius: Double = 24
    public var shadowOpacity: Double = 0.35

    public var hoverEffect: HoverEffect = .magnify
    /// Peak scale under the pointer (1 = no magnification).
    public var magnification: Double = 1.6
    /// How many neighbouring icons (each side) are affected by magnification.
    public var magnificationSpread: Double = 2.5

    public var labelMode: LabelMode = .onHover
    public var labelFontSize: Double = 12
    public var categoryHeaderStyle: CategoryHeaderStyle = .pill
    /// Gap between categories, in points.
    public var categorySpacing: Double = 14
    public var runningIndicator: RunningIndicator = .dot

    /// Multiplier for every animation duration (0.5 = twice as fast, 0 = no animation).
    public var animationSpeed: Double = 1.0

    public init() {}

    // MARK: Ranges used by the editor UI and by `sanitized()`

    public static let iconSizeRange: ClosedRange<Double> = 16...128
    public static let spacingRange: ClosedRange<Double> = 0...40
    public static let paddingRange: ClosedRange<Double> = 0...40
    public static let cornerRadiusRange: ClosedRange<Double> = 0...60
    public static let borderWidthRange: ClosedRange<Double> = 0...6
    public static let shadowRadiusRange: ClosedRange<Double> = 0...60
    public static let magnificationRange: ClosedRange<Double> = 1...3
    public static let magnificationSpreadRange: ClosedRange<Double> = 1...6
    public static let labelFontSizeRange: ClosedRange<Double> = 9...20
    public static let categorySpacingRange: ClosedRange<Double> = 0...48
    public static let animationSpeedRange: ClosedRange<Double> = 0...3

    /// Returns a copy with every value clamped to its legal range.
    public func sanitized() -> DockAppearance {
        var a = self
        a.tintOpacity = a.tintOpacity.clamped(to: 0...1)
        a.backgroundOpacity = a.backgroundOpacity.clamped(to: 0...1)
        a.iconSize = a.iconSize.clamped(to: Self.iconSizeRange)
        a.iconSpacing = a.iconSpacing.clamped(to: Self.spacingRange)
        a.padding = a.padding.clamped(to: Self.paddingRange)
        a.cornerRadius = a.cornerRadius.clamped(to: Self.cornerRadiusRange)
        a.borderWidth = a.borderWidth.clamped(to: Self.borderWidthRange)
        a.shadowRadius = a.shadowRadius.clamped(to: Self.shadowRadiusRange)
        a.shadowOpacity = a.shadowOpacity.clamped(to: 0...1)
        a.magnification = a.magnification.clamped(to: Self.magnificationRange)
        a.magnificationSpread = a.magnificationSpread.clamped(to: Self.magnificationSpreadRange)
        a.labelFontSize = a.labelFontSize.clamped(to: Self.labelFontSizeRange)
        a.categorySpacing = a.categorySpacing.clamped(to: Self.categorySpacingRange)
        a.animationSpeed = a.animationSpeed.clamped(to: Self.animationSpeedRange)
        return a
    }

    enum CodingKeys: String, CodingKey {
        case mode, material, tint, tintOpacity, backgroundOpacity, gradientEnd, accent
        case iconSize, iconSpacing, iconShape, iconShadow, padding, cornerRadius
        case borderWidth, borderColor, shadowRadius, shadowOpacity
        case hoverEffect, magnification, magnificationSpread
        case labelMode, labelFontSize, categoryHeaderStyle, categorySpacing, runningIndicator
        case animationSpeed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DockAppearance()
        mode = c.decode(.mode, default: d.mode)
        material = c.decode(.material, default: d.material)
        tint = c.decode(.tint, default: d.tint)
        tintOpacity = c.decode(.tintOpacity, default: d.tintOpacity)
        backgroundOpacity = c.decode(.backgroundOpacity, default: d.backgroundOpacity)
        gradientEnd = c.decode(.gradientEnd, default: d.gradientEnd)
        accent = c.decode(.accent, default: d.accent)
        iconSize = c.decode(.iconSize, default: d.iconSize)
        iconSpacing = c.decode(.iconSpacing, default: d.iconSpacing)
        iconShape = c.decode(.iconShape, default: d.iconShape)
        iconShadow = c.decode(.iconShadow, default: d.iconShadow)
        padding = c.decode(.padding, default: d.padding)
        cornerRadius = c.decode(.cornerRadius, default: d.cornerRadius)
        borderWidth = c.decode(.borderWidth, default: d.borderWidth)
        borderColor = c.decode(.borderColor, default: d.borderColor)
        shadowRadius = c.decode(.shadowRadius, default: d.shadowRadius)
        shadowOpacity = c.decode(.shadowOpacity, default: d.shadowOpacity)
        hoverEffect = c.decode(.hoverEffect, default: d.hoverEffect)
        magnification = c.decode(.magnification, default: d.magnification)
        magnificationSpread = c.decode(.magnificationSpread, default: d.magnificationSpread)
        labelMode = c.decode(.labelMode, default: d.labelMode)
        labelFontSize = c.decode(.labelFontSize, default: d.labelFontSize)
        categoryHeaderStyle = c.decode(.categoryHeaderStyle, default: d.categoryHeaderStyle)
        categorySpacing = c.decode(.categorySpacing, default: d.categorySpacing)
        runningIndicator = c.decode(.runningIndicator, default: d.runningIndicator)
        animationSpeed = c.decode(.animationSpeed, default: d.animationSpeed)
    }
}
