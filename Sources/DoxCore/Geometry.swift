import Foundation

/// Math for the dock layout, independent of AppKit so it can be unit tested.
public enum DockGeometry {

    /// Scale for an icon given its distance (in points, along the dock axis) from the pointer.
    /// Uses a cosine falloff: 1 at the pointer → 1 at `spread * iconSize` away, smooth in between.
    public static func magnificationScale(distance: Double,
                                          iconSize: Double,
                                          magnification: Double,
                                          spread: Double) -> Double {
        guard magnification > 1, iconSize > 0, spread > 0 else { return 1 }
        let reach = spread * iconSize
        let d = abs(distance)
        guard d < reach else { return 1 }
        let t = d / reach                         // 0 at pointer … 1 at edge of reach
        let falloff = (cos(t * .pi) + 1) / 2      // 1 … 0
        return 1 + (magnification - 1) * falloff
    }

    /// How many icon "lines" (rows for horizontal docks, columns for vertical) a dock uses.
    public static func lineCount(for dock: DockConfig) -> Int {
        switch dock.layout {
        case .line: return 1
        case .grid: return max(1, min(dock.gridLines, max(dock.visibleTileCount, 1)))
        case .shelves: return max(1, dock.visibleCategories.count)
        }
    }

    /// Resting (un-magnified) size of the dock body.
    /// - Returns: (length along the edge, thickness away from the edge).
    public static func restingSize(for dock: DockConfig, headerExtent: Double = 0) -> (length: Double, thickness: Double) {
        let a = dock.appearance
        let cats = dock.visibleCategories
        guard !cats.isEmpty else {
            return (a.iconSize + a.padding * 2, a.iconSize + a.padding * 2)
        }
        let tile = a.iconSize
        let lines = lineCount(for: dock)

        switch dock.layout {
        case .line:
            var length = 0.0
            for (i, c) in cats.enumerated() {
                let n = Double(c.display == .stack ? 1 : c.items.count)
                length += n * tile + max(0, n - 1) * a.iconSpacing
                length += headerExtent
                if i < cats.count - 1 { length += a.categorySpacing }
            }
            return (length + a.padding * 2, tile + a.padding * 2)

        case .grid:
            let tiles = Double(dock.visibleTileCount)
            let perLine = (tiles / Double(lines)).rounded(.up)
            let length = perLine * tile + max(0, perLine - 1) * a.iconSpacing
            let thickness = Double(lines) * tile + Double(lines - 1) * a.iconSpacing
            return (length + a.padding * 2 + headerExtent, thickness + a.padding * 2)

        case .shelves:
            let longest = cats.map { Double($0.display == .stack ? 1 : $0.items.count) }.max() ?? 1
            let length = longest * tile + max(0, longest - 1) * a.iconSpacing + headerExtent
            let thickness = Double(lines) * tile + Double(lines - 1) * a.categorySpacing
            return (length + a.padding * 2, thickness + a.padding * 2)
        }
    }

    /// Extra room the panel needs beyond the resting body so magnified icons are not clipped.
    public static func magnificationHeadroom(for appearance: DockAppearance) -> Double {
        guard appearance.hoverEffect == .magnify else {
            return appearance.hoverEffect == .lift ? appearance.iconSize * 0.3 : 8
        }
        return appearance.iconSize * (appearance.magnification - 1)
    }

    /// Origin of the dock body inside a screen's visible frame (bottom-left origin, like AppKit).
    public static func origin(bodyWidth: Double, bodyHeight: Double,
                              screenX: Double, screenY: Double, screenWidth: Double, screenHeight: Double,
                              edge: DockEdge, alignment: EdgeAlignment, offset: Double, inset: Double) -> (x: Double, y: Double) {
        func place(available: Double, size: Double, start: Double) -> Double {
            let free = available - size
            let base: Double
            switch alignment {
            case .leading: base = 0
            case .center: base = free / 2
            case .trailing: base = free
            }
            let shifted = base + offset.clamped(to: -0.5...0.5) * available
            return start + shifted.clamped(to: 0...max(0, free))
        }
        switch edge {
        case .left:
            // "leading" on a vertical edge means top of screen.
            let y = place(available: screenHeight, size: bodyHeight, start: screenY)
            return (screenX + inset, screenY + screenHeight - bodyHeight - (y - screenY))
        case .right:
            let y = place(available: screenHeight, size: bodyHeight, start: screenY)
            return (screenX + screenWidth - bodyWidth - inset, screenY + screenHeight - bodyHeight - (y - screenY))
        case .top:
            let x = place(available: screenWidth, size: bodyWidth, start: screenX)
            return (x, screenY + screenHeight - bodyHeight - inset)
        case .bottom:
            let x = place(available: screenWidth, size: bodyWidth, start: screenX)
            return (x, screenY + inset)
        }
    }
}
