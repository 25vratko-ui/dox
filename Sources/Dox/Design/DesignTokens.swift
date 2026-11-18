import SwiftUI
import AppKit

/// Design tokens for the settings window. See DESIGN.md.
/// Note: inside `DS`, `Font` and `Color` refer to the nested token enums,
/// so SwiftUI types are spelled `SwiftUI.Font` / `SwiftUI.Color` here.
enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let s: CGFloat = 6
        static let m: CGFloat = 10
        static let l: CGFloat = 14
    }

    enum Font {
        static let sectionTitle = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let rowTitle = SwiftUI.Font.system(size: 13, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 11, weight: .regular)
        static let mono = SwiftUI.Font.system(size: 11, weight: .medium, design: .monospaced)
    }

    enum Color {
        /// Card fill: near-white lift in light mode, faint glass in dark mode.
        static let cardBackground = dynamic(light: NSColor(white: 1, alpha: 0.72),
                                            dark: NSColor(white: 1, alpha: 0.045))
        /// Hairline card border.
        static let cardBorder = dynamic(light: NSColor(white: 0, alpha: 0.08),
                                        dark: NSColor(white: 1, alpha: 0.09))
        static let secondaryText = SwiftUI.Color.secondary
        /// Dox indigo – deeper in light mode for contrast on white.
        static let accent = dynamic(light: NSColor(srgbRed: 0.33, green: 0.38, blue: 0.86, alpha: 1),
                                    dark: NSColor(srgbRed: 0.49, green: 0.55, blue: 1.0, alpha: 1))
        /// Background of value readouts (capsules next to sliders, hex codes).
        static let readoutBackground = dynamic(light: NSColor(white: 0, alpha: 0.05),
                                               dark: NSColor(white: 1, alpha: 0.07))
        /// Separator between rows inside a card.
        static let rowSeparator = dynamic(light: NSColor(white: 0, alpha: 0.06),
                                          dark: NSColor(white: 1, alpha: 0.06))

        static func dynamic(light: NSColor, dark: NSColor) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            })
        }
    }

    enum Layout {
        /// Width of the aligned label column in settings rows.
        static let labelWidth: CGFloat = 150
        /// Width of numeric readouts next to sliders.
        static let readoutWidth: CGFloat = 58
        /// Minimum row height so mixed controls line up.
        static let rowHeight: CGFloat = 26
    }

    enum Motion {
        /// The Dox spring: response 0.35, damping 0.8, scaled by `animationSpeed`.
        /// Returns nil (no animation) when speed is 0.
        static func spring(speed: Double = 1) -> Animation? {
            guard speed > 0 else { return nil }
            return .spring(response: 0.35 * speed, dampingFraction: 0.8)
        }

        /// Quick UI feedback (hover, selection) – not scaled.
        static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.85)
    }
}
