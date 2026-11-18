import AppKit
import UniformTypeIdentifiers
import DoxCore

/// Icons for dock items, cached.
@MainActor
final class IconProvider {
    static let shared = IconProvider()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 600
    }

    /// Drops every cached icon (e.g. after apps were updated).
    func invalidate() {
        cache.removeAllObjects()
    }

    /// Icon for a dock item. A `customSymbol` always wins; links without one use `globe`.
    func icon(for item: DockItem, size: CGFloat) -> NSImage {
        let tint = item.tint.map(Self.nsColor)
        let key = "\(item.kind.identityKey)|\(item.customSymbol ?? "")|\(item.tint?.hexString ?? "")|\(Int(size.rounded()))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let image: NSImage
        if let symbol = item.customSymbol, !symbol.isEmpty {
            image = symbolImage(symbol, size: size, tint: tint)
        } else {
            switch item.kind {
            case .app(let path, let bundleID):
                if FileManager.default.fileExists(atPath: path) {
                    image = sized(NSWorkspace.shared.icon(forFile: path), size)
                } else if let bundleID, let icon = appIcon(bundleID: bundleID) {
                    image = sized(icon, size)
                } else {
                    image = sized(NSWorkspace.shared.icon(for: .applicationBundle), size)
                }
            case .folder(let path), .file(let path):
                image = sized(NSWorkspace.shared.icon(forFile: path), size)
            case .link:
                image = symbolImage("globe", size: size, tint: tint)
            case .separator:
                image = symbolImage("line.diagonal", size: size, tint: tint)
            case .spacer:
                image = NSImage(size: NSSize(width: size, height: size))
            }
        }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Icon of an installed app by bundle identifier.
    func appIcon(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// An SF Symbol rendered centred on a `size`×`size` canvas. Without `tint` the result is a
    /// template image (SwiftUI can colour it); with `tint` it is pre-coloured.
    func symbolImage(_ name: String, size: CGFloat, tint: NSColor?) -> NSImage {
        let key = "sym|\(name)|\(Int(size.rounded()))|\(tint.map { Self.hex($0) } ?? "")" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let config = NSImage.SymbolConfiguration(pointSize: max(6, size * 0.58), weight: .medium)
        let base = (NSImage(systemSymbolName: name, accessibilityDescription: name)
                    ?? NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil)
                    ?? NSImage())
        let symbol = base.withSymbolConfiguration(config) ?? base
        let canvas = NSSize(width: size, height: size)
        let image = NSImage(size: canvas, flipped: false) { rect in
            let s = symbol.size
            let target = NSRect(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2,
                                width: s.width, height: s.height)
            symbol.draw(in: target)
            if let tint {
                tint.set()
                rect.fill(using: .sourceAtop)
            }
            return true
        }
        image.isTemplate = (tint == nil)
        cache.setObject(image, forKey: key)
        return image
    }

    // MARK: Helpers

    private func sized(_ image: NSImage, _ size: CGFloat) -> NSImage {
        let copy = (image.copy() as? NSImage) ?? image
        copy.size = NSSize(width: size, height: size)
        return copy
    }

    private static func nsColor(_ c: RGBAColor) -> NSColor {
        NSColor(srgbRed: CGFloat(c.red), green: CGFloat(c.green), blue: CGFloat(c.blue), alpha: CGFloat(c.alpha))
    }

    private static func hex(_ color: NSColor) -> String {
        guard let c = color.usingColorSpace(.sRGB) else { return color.description }
        return RGBAColor(red: Double(c.redComponent), green: Double(c.greenComponent),
                         blue: Double(c.blueComponent), alpha: Double(c.alphaComponent)).hexString
    }
}
