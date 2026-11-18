import Foundation

// MARK: - Color

/// Platform-independent RGBA color (0...1 components) that is Codable and stable on disk.
public struct RGBAColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
        self.alpha = alpha.clamped(to: 0...1)
    }

    /// Accepts `#RGB`, `#RRGGBB` or `#RRGGBBAA` (the `#` is optional).
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6 || s.count == 8, s.allSatisfy(\.isHexDigit), let value = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(red: Double((value >> 16) & 0xFF) / 255,
                      green: Double((value >> 8) & 0xFF) / 255,
                      blue: Double(value & 0xFF) / 255)
        } else {
            self.init(red: Double((value >> 24) & 0xFF) / 255,
                      green: Double((value >> 16) & 0xFF) / 255,
                      blue: Double((value >> 8) & 0xFF) / 255,
                      alpha: Double(value & 0xFF) / 255)
        }
    }

    /// `#RRGGBB` when opaque, `#RRGGBBAA` otherwise.
    public var hexString: String {
        func c(_ v: Double) -> String { String(format: "%02X", Int((v * 255).rounded())) }
        let base = "#" + c(red) + c(green) + c(blue)
        return alpha >= 0.999 ? base : base + c(alpha)
    }

    public func withAlpha(_ a: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: a)
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
    public static let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
}

// MARK: - Geometry enums

public enum DockEdge: String, Codable, CaseIterable, Sendable, Identifiable {
    case left, right, top, bottom
    public var id: String { rawValue }
    /// Items flow vertically on left/right docks.
    public var isVertical: Bool { self == .left || self == .right }
    public var displayName: String {
        switch self {
        case .left: "Vľavo"
        case .right: "Vpravo"
        case .top: "Hore"
        case .bottom: "Dole"
        }
    }
}

/// Where along the edge the dock sits.
public enum EdgeAlignment: String, Codable, CaseIterable, Sendable, Identifiable {
    case leading, center, trailing
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .leading: "Začiatok"
        case .center: "Stred"
        case .trailing: "Koniec"
        }
    }
}

public enum DisplayTarget: Codable, Hashable, Sendable {
    /// The display with the menu bar.
    case main
    /// Whichever display the mouse pointer is on (follows the pointer).
    case withMouse
    /// A specific display identified by its localized name.
    case named(String)
    /// One copy of the dock on every connected display.
    case all
}

// MARK: - Keyboard shortcut

/// A global keyboard shortcut stored as a virtual key code plus modifier set.
public struct KeyShortcut: Codable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }

    /// macOS virtual key code (kVK_*).
    public var keyCode: UInt32
    public var modifiers: Modifiers
    /// Human readable key label captured when recording (e.g. "D", "Space", "F5").
    public var keyLabel: String

    public init(keyCode: UInt32, modifiers: Modifiers, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// e.g. "⌃⌥⌘D" in the standard macOS modifier order.
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + keyLabel.uppercased()
    }

    /// Same physical key combination, regardless of the recorded label.
    public func matches(_ other: KeyShortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }

    /// A shortcut without any modifier would hijack normal typing.
    public var isValidGlobalShortcut: Bool { !modifiers.isEmpty }
}

// MARK: - Helpers

extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Decodes an array, skipping elements that fail to decode instead of failing the whole array.
struct LossyArray<Element: Decodable>: Decodable {
    var elements: [Element]

    /// Accepts any JSON value so the container always advances past a bad element.
    private struct Skip: Decodable { init(from decoder: Decoder) throws {} }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let value = try? container.decode(Element.self) {
                result.append(value)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        elements = result
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value, falling back to `defaultValue` when the key is missing or malformed.
    /// Keeps old config files loadable as new settings are added.
    func decode<T: Decodable>(_ key: Key, default defaultValue: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? defaultValue()
    }
}
