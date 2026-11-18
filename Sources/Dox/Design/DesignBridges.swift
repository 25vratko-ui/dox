import SwiftUI
import AppKit
import DoxCore

// MARK: - Color <-> RGBAColor

extension Color {
    /// SwiftUI color from the platform-independent model color (sRGB).
    init(_ rgba: RGBAColor) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}

extension RGBAColor {
    /// Model color from a SwiftUI color. Falls back to white when the color
    /// cannot be expressed in sRGB (e.g. pattern colors).
    init(_ color: Color) {
        var r = 1.0, g = 1.0, b = 1.0, a = 1.0
        if let ns = NSColor(color).usingColorSpace(.sRGB) {
            r = Double(ns.redComponent)
            g = Double(ns.greenComponent)
            b = Double(ns.blueComponent)
            a = Double(ns.alphaComponent)
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    /// Linear blend towards `other` (0 = self, 1 = other). Alpha is blended too.
    func mixed(with other: RGBAColor, amount: Double) -> RGBAColor {
        let t = amount.clamped(to: 0...1)
        return RGBAColor(red: red + (other.red - red) * t,
                         green: green + (other.green - green) * t,
                         blue: blue + (other.blue - blue) * t,
                         alpha: alpha + (other.alpha - alpha) * t)
    }

    /// Relative luminance (sRGB approximation), 0 = black, 1 = white.
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }
}

// MARK: - Appearance mode

extension AppearanceMode {
    /// `nil` means "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// `nil` means "inherit the effective appearance".
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - Material

extension DockMaterial {
    /// Closest NSVisualEffectView material. `nil` for the non-blur modes (`solid`, `clear`).
    /// macOS has no "thickness" scale, so the glass steps are ordered from the most
    /// see-through system material to the most opaque one.
    var nsMaterial: NSVisualEffectView.Material? {
        switch self {
        case .ultraThin: .fullScreenUI
        case .thin: .headerView
        case .regular: .titlebar
        case .thick: .sheet
        case .ultraThick: .windowBackground
        case .hud: .hudWindow
        case .sidebar: .sidebar
        case .menu: .menu
        case .popover: .popover
        case .solid, .clear: nil
        }
    }

    /// True for the materials that blur what is behind the window.
    var isBlurred: Bool { nsMaterial != nil }
}
