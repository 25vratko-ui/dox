import AppKit
import SwiftUI
import DoxCore

/// Borderless, non-activating, transparent panel hosting one dock.
///
/// Created with `DockPanel(contentRect:styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)`
/// and configured by `DockPanelController`.
final class DockPanel: NSPanel {
    /// Can become key so text fields / popovers inside the dock work; `becomesKeyOnlyIfNeeded`
    /// keeps plain clicks from stealing focus.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Auto-hide slides the panel partly off-screen; never let AppKit pull it back.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Root SwiftUI content of a dock panel.
///
/// Expected contract with `DockRootView`: it sizes itself to the dock body (resting size,
/// growing with magnification) and does not fill the whole panel. This wrapper then pins it
/// against the screen edge:
/// - left edge → `.leading` (body at the panel's left side, vertically centred)
/// - right edge → `.trailing`
/// - top edge → `.top` (horizontally centred)
/// - bottom edge → `.bottom`
/// The free space on the opposite side is magnification / label headroom; `margin` on every
/// side leaves room for the dock's shadow.
struct DockPanelContent: View, Equatable {
    let dockID: UUID
    let margin: CGFloat
    let edge: DockEdge

    var body: some View {
        DockRootView(dockID: dockID)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(margin)
            .ignoresSafeArea()
    }

    private var alignment: Alignment {
        switch edge {
        case .left: return .leading
        case .right: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        }
    }
}

/// Every rectangle the panel controller needs, in global (bottom-left origin) screen coordinates.
struct DockPanelLayout {
    /// Panel frame while the dock is shown.
    var frame: NSRect = .zero
    /// Panel frame while auto-hidden (2 pt sliver of the body left on screen).
    var collapsedFrame: NSRect = .zero
    /// Resting dock body.
    var bodyRect: NSRect = .zero
    /// While the pointer is inside the dock, it stays "inside" (panel accepts clicks) within this
    /// larger rect: body + magnification headroom + the gap towards the screen edge.
    var activeRect: NSRect = .zero
    /// Pointer inside this rect keeps an auto-hide dock open (body + gap to the edge + slack).
    var engagedRect: NSRect = .zero
    /// Resting here for `revealDelay` reveals an auto-hidden dock.
    var revealZones: [NSRect] = []
    /// Transparent margin on every side for the dock's shadow.
    var margin: CGFloat = 0
    /// The collapsed body would spill onto a neighbouring display → fade out instead.
    var collapsedLeaksOntoOtherScreen = false

    init() {}

    @MainActor
    init(dock: DockConfig, screen: NSScreen) {
        let a = dock.appearance
        let edge = dock.edge
        let v = screen.visibleFrame
        let s = screen.frame

        let size = Self.bodySize(for: dock)
        let o = DockGeometry.origin(bodyWidth: Double(size.width), bodyHeight: Double(size.height),
                                    screenX: Double(v.minX), screenY: Double(v.minY),
                                    screenWidth: Double(v.width), screenHeight: Double(v.height),
                                    edge: edge,
                                    alignment: dock.behavior.alignment,
                                    offset: dock.behavior.alignmentOffset,
                                    inset: dock.behavior.edgeInset)
        let body = NSRect(x: CGFloat(o.x).rounded(), y: CGFloat(o.y).rounded(),
                          width: size.width, height: size.height)

        let headroom = CGFloat(DockGeometry.magnificationHeadroom(for: a))
        let labelRoom: CGFloat
        switch a.labelMode {
        case .never: labelRoom = 0
        case .onHover, .always: labelRoom = edge.isVertical ? 180 : CGFloat(a.labelFontSize) + 18
        }
        let away = ceil(headroom + labelRoom + 4)
        var along = headroom
        if a.hoverEffect == .magnify {
            // Total extra length of a magnified line ≈ (mag - 1) * spread * iconSize, half per side.
            along = max(along, CGFloat((a.magnification - 1) * a.magnificationSpread * a.iconSize / 2))
        }
        along = ceil(along + (edge.isVertical ? 8 : 48)) // horizontal hover labels can be wider than icons
        let m = ceil(CGFloat(a.shadowRadius) + 6)

        let gap: CGFloat
        switch edge {
        case .left: gap = max(0, body.minX - s.minX)
        case .right: gap = max(0, s.maxX - body.maxX)
        case .bottom: gap = max(0, body.minY - s.minY)
        case .top: gap = max(0, s.maxY - body.maxY)
        }

        bodyRect = body
        margin = m
        frame = Self.extend(body, edge: edge, toward: m, away: away + m, along: along + m)
        activeRect = Self.extend(body, edge: edge, toward: gap + 1, away: headroom + 4, along: along)
        engagedRect = Self.extend(body, edge: edge, toward: gap + 1, away: 6, along: 6)

        // Slide so only 2 pt of the body remains inside the visible frame.
        let dx: CGFloat, dy: CGFloat
        switch edge {
        case .left: dx = -(body.maxX - (v.minX + 2)); dy = 0
        case .right: dx = (v.maxX - 2) - body.minX; dy = 0
        case .bottom: dx = 0; dy = -(body.maxY - (v.minY + 2))
        case .top: dx = 0; dy = (v.maxY - 2) - body.minY
        }
        collapsedFrame = frame.offsetBy(dx: dx, dy: dy)
        let collapsedBody = body.offsetBy(dx: dx, dy: dy)
        let ownID = screen.displayID
        collapsedLeaksOntoOtherScreen = NSScreen.screens.contains {
            $0.displayID != ownID && $0.frame.intersects(collapsedBody)
        }

        // Thin strips at the visible-frame edge (where the sliver is) and at the physical
        // screen edge (differs e.g. under the menu bar), limited to the dock's span.
        switch edge {
        case .left:
            revealZones = [NSRect(x: s.minX - 1, y: body.minY - 8, width: 5, height: body.height + 16),
                           NSRect(x: v.minX - 1, y: body.minY - 8, width: 5, height: body.height + 16)]
        case .right:
            revealZones = [NSRect(x: s.maxX - 4, y: body.minY - 8, width: 5, height: body.height + 16),
                           NSRect(x: v.maxX - 4, y: body.minY - 8, width: 5, height: body.height + 16)]
        case .bottom:
            revealZones = [NSRect(x: body.minX - 8, y: s.minY - 1, width: body.width + 16, height: 5),
                           NSRect(x: body.minX - 8, y: v.minY - 1, width: body.width + 16, height: 5)]
        case .top:
            revealZones = [NSRect(x: body.minX - 8, y: s.maxY - 4, width: body.width + 16, height: 5),
                           NSRect(x: body.minX - 8, y: v.maxY - 4, width: body.width + 16, height: 5)]
        }
    }

    /// Extent of one category header along the dock's length axis, passed to
    /// `DockGeometry.restingSize(for:headerExtent:)`. DockRootView should use the same value.
    static func headerExtent(for dock: DockConfig) -> Double {
        let a = dock.appearance
        switch a.categoryHeaderStyle {
        case .hidden, .divider: return 0
        case .pill: return 22 + a.iconSpacing
        case .label: return a.labelFontSize + 10 + a.iconSpacing
        }
    }

    /// Resting body size in points (width × height on screen).
    static func bodySize(for dock: DockConfig) -> CGSize {
        let r = DockGeometry.restingSize(for: dock, headerExtent: headerExtent(for: dock))
        // A dock whose categories are all empty still shows one drop-target tile.
        let minLength = CGFloat(dock.appearance.iconSize + dock.appearance.padding * 2)
        let length = max(ceil(CGFloat(r.length)), minLength)
        let thickness = ceil(CGFloat(r.thickness))
        return dock.edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)
    }

    /// Grows `r` by `toward` on the screen-edge side, `away` on the opposite side and `along`
    /// at both ends of the dock's length axis.
    static func extend(_ r: NSRect, edge: DockEdge, toward: CGFloat, away: CGFloat, along: CGFloat) -> NSRect {
        switch edge {
        case .left:
            return NSRect(x: r.minX - toward, y: r.minY - along,
                          width: r.width + toward + away, height: r.height + 2 * along)
        case .right:
            return NSRect(x: r.minX - away, y: r.minY - along,
                          width: r.width + toward + away, height: r.height + 2 * along)
        case .bottom:
            return NSRect(x: r.minX - along, y: r.minY - toward,
                          width: r.width + 2 * along, height: r.height + toward + away)
        case .top:
            return NSRect(x: r.minX - along, y: r.minY - away,
                          width: r.width + 2 * along, height: r.height + toward + away)
        }
    }
}
