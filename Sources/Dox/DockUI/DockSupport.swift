import SwiftUI
import AppKit
import DoxCore

// MARK: - Coordinate space & slot reporting

/// Name of the coordinate space every tile reports its resting frame in.
enum DockSpace {
    static let name = "dox.dock.space"
}

/// An addressable, measurable slot inside a rendered dock.
enum DockSlot: Hashable {
    case item(UUID)
    case stack(UUID)
    case header(UUID)
}

/// Resting geometry of one slot (before magnification offsets).
struct DockSlotInfo: Equatable {
    var frame: CGRect
    /// Line (row/column/shelf) the slot belongs to. Displacement is computed per line.
    var line: Int
    /// Headers, separators and spacers move with their neighbours but never grow.
    var magnifies: Bool
}

struct DockSlotFrameKey: PreferenceKey {
    static let defaultValue: [DockSlot: DockSlotInfo] = [:]
    static func reduce(value: inout [DockSlot: DockSlotInfo], nextValue: () -> [DockSlot: DockSlotInfo]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Per-tile visual state derived from the pointer position.
struct TileEffect: Equatable {
    var scale: CGFloat = 1
    /// Displacement along the dock axis (keeps magnified neighbours from overlapping).
    var shift: CGFloat = 0
    /// Displacement away from the screen edge (`.lift` hover effect).
    var lift: CGFloat = 0
    var glow: Bool = false
    var isHovered: Bool = false

    static let rest = TileEffect()
}

extension View {
    /// Reports this view's resting frame (in `DockSpace`) for magnification math.
    /// Must be applied *outside* any `.offset` so the reported frame never moves with the effect.
    func dockSlot(_ slot: DockSlot, line: Int, magnifies: Bool = true) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DockSlotFrameKey.self,
                    value: [slot: DockSlotInfo(frame: geo.frame(in: .named(DockSpace.name)),
                                               line: line,
                                               magnifies: magnifies)]
                )
            }
        )
    }

    /// Frame expressed along / across the dock axis.
    func axisFrame(along: CGFloat, cross: CGFloat, vertical: Bool) -> some View {
        frame(width: vertical ? cross : along, height: vertical ? along : cross)
    }
}

// MARK: - Edge helpers

extension DockEdge {
    /// Alignment that pins the dock body to this screen edge inside a larger panel.
    var bodyAlignment: Alignment {
        switch self {
        case .left: .leading
        case .right: .trailing
        case .top: .top
        case .bottom: .bottom
        }
    }

    /// Anchor on the edge side of a tile: scaling around it grows the tile away from the edge.
    var towardAnchor: UnitPoint {
        switch self {
        case .left: .leading
        case .right: .trailing
        case .top: .top
        case .bottom: .bottom
        }
    }

    /// Overlay alignment on the side of a tile facing the screen edge.
    var towardAlignment: Alignment { bodyAlignment }

    /// Overlay alignment on the side of a tile facing away from the screen edge.
    var awayAlignment: Alignment {
        switch self {
        case .left: .trailing
        case .right: .leading
        case .top: .bottom
        case .bottom: .top
        }
    }

    /// Side of a tile facing away from the screen (popover arrows, labels, headroom).
    var awayEdge: Edge {
        switch self {
        case .left: .trailing
        case .right: .leading
        case .top: .bottom
        case .bottom: .top
        }
    }

    /// +1 / -1: direction of "away from the edge" on the cross axis, in SwiftUI coordinates (y down).
    var awaySign: CGFloat {
        switch self {
        case .left, .top: 1
        case .right, .bottom: -1
        }
    }

    /// Offset of `distance` points away from the edge.
    func awayOffset(_ distance: CGFloat) -> CGSize {
        isVertical ? CGSize(width: awaySign * distance, height: 0) : CGSize(width: 0, height: awaySign * distance)
    }

    /// SF Symbol describing a dock on this edge.
    var symbol: String {
        switch self {
        case .left: "rectangle.lefthalf.inset.filled"
        case .right: "rectangle.righthalf.inset.filled"
        case .top: "rectangle.tophalf.inset.filled"
        case .bottom: "rectangle.bottomhalf.inset.filled"
        }
    }
}

// MARK: - Motion

enum DockMotion {
    /// Fast, interactive spring for pointer-driven changes. `nil` when animations are off.
    static func hover(_ a: DockAppearance) -> Animation? {
        guard a.animationSpeed > 0.01 else { return nil }
        return .spring(response: 0.2 * a.animationSpeed, dampingFraction: 0.82)
    }

    /// Softer spring for state changes (labels, drop targets, popovers).
    static func standard(_ a: DockAppearance) -> Animation? {
        guard a.animationSpeed > 0.01 else { return nil }
        return .spring(response: 0.36 * a.animationSpeed, dampingFraction: 0.8)
    }
}

// MARK: - Magnification

enum DockMagnifier {
    /// Computes the visual effect of every slot for the current pointer position.
    /// - Parameters:
    ///   - multiLine: grid / shelves – distance is measured in 2D so only nearby lines grow.
    static func effects(pointer: CGPoint?,
                        slots: [DockSlot: DockSlotInfo],
                        appearance a: DockAppearance,
                        vertical: Bool,
                        multiLine: Bool) -> [DockSlot: TileEffect] {
        guard let p = pointer, !slots.isEmpty else { return [:] }
        let iconSize = CGFloat(a.iconSize)
        let slop = CGFloat(a.iconSpacing) / 2

        func along(_ pt: CGPoint) -> CGFloat { vertical ? pt.y : pt.x }
        func center(_ r: CGRect) -> CGPoint { CGPoint(x: r.midX, y: r.midY) }

        var hovered: DockSlot?
        for (key, info) in slots where info.magnifies {
            if info.frame.insetBy(dx: -slop, dy: -slop).contains(p) { hovered = key; break }
        }

        var out: [DockSlot: TileEffect] = [:]
        switch a.hoverEffect {
        case .magnify:
            let pa = along(p)
            let groups = Dictionary(grouping: slots, by: { $0.value.line })
            for (_, members) in groups {
                let sorted = members.sorted { along(center($0.value.frame)) < along(center($1.value.frame)) }
                var extras: [CGFloat] = []
                extras.reserveCapacity(sorted.count)
                var growthBeforePointer: CGFloat = 0
                for member in sorted {
                    let info = member.value
                    let c = center(info.frame)
                    var scale: CGFloat = 1
                    if info.magnifies {
                        let distance: CGFloat = multiLine ? hypot(c.x - p.x, c.y - p.y) : along(c) - pa
                        scale = CGFloat(DockGeometry.magnificationScale(distance: Double(distance),
                                                                         iconSize: a.iconSize,
                                                                         magnification: a.magnification,
                                                                         spread: a.magnificationSpread))
                    }
                    let extra = (scale - 1) * iconSize
                    extras.append(extra)
                    let lo = vertical ? info.frame.minY : info.frame.minX
                    let len = max(1, vertical ? info.frame.height : info.frame.width)
                    let fraction = min(1, max(0, (pa - lo) / len))
                    growthBeforePointer += extra * fraction
                }
                // Lay the grown tiles out virtually, then shift so the point under the pointer stays put.
                var running: CGFloat = 0
                for (i, member) in sorted.enumerated() {
                    let shift = running + extras[i] / 2 - growthBeforePointer
                    running += extras[i]
                    out[member.key] = TileEffect(scale: 1 + extras[i] / max(iconSize, 1),
                                                 shift: shift,
                                                 isHovered: member.key == hovered)
                }
            }
        case .lift:
            if let hovered { out[hovered] = TileEffect(scale: 1.04, lift: iconSize * 0.22, isHovered: true) }
        case .glow:
            if let hovered { out[hovered] = TileEffect(scale: 1.06, glow: true, isHovered: true) }
        case .none:
            if let hovered { out[hovered] = TileEffect(isHovered: true) }
        }
        return out
    }
}

// MARK: - Shapes & modifiers

/// A rectangle inset by edge insets – used as hit shape so transparent headroom only
/// captures the pointer while the dock is already being hovered.
struct DockHitShape: Shape {
    var insets: EdgeInsets

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX + insets.leading,
                    y: rect.minY + insets.top,
                    width: max(0, rect.width - insets.leading - insets.trailing),
                    height: max(0, rect.height - insets.top - insets.bottom)))
    }
}

/// Applies the dock's appearance mode (light / dark / system).
struct DockColorSchemeModifier: ViewModifier {
    let mode: AppearanceMode

    @ViewBuilder
    func body(content: Content) -> some View {
        if let scheme = mode.colorScheme {
            content.environment(\.colorScheme, scheme)
        } else {
            content
        }
    }
}

/// Places an overlay just outside its parent, on the side away from the screen edge.
/// Use inside `.overlay(alignment: edge.awayAlignment)`.
struct AwayPlacement: ViewModifier {
    let edge: DockEdge
    let gap: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch edge {
        case .bottom:
            content.alignmentGuide(VerticalAlignment.top) { d in d[VerticalAlignment.bottom] + gap }
        case .top:
            content.alignmentGuide(VerticalAlignment.bottom) { d in d[VerticalAlignment.top] - gap }
        case .left:
            content.alignmentGuide(HorizontalAlignment.trailing) { d in d[HorizontalAlignment.leading] - gap }
        case .right:
            content.alignmentGuide(HorizontalAlignment.leading) { d in d[HorizontalAlignment.trailing] + gap }
        }
    }
}

// MARK: - Slovak plurals

enum SK {
    /// Slovak plural form: 1 položka, 2–4 položky, 0/5+ položiek.
    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        switch n {
        case 1: return "\(n) \(one)"
        case 2...4: return "\(n) \(few)"
        default: return "\(n) \(many)"
        }
    }

    static func items(_ n: Int) -> String { plural(n, "položka", "položky", "položiek") }
}
