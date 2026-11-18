import SwiftUI
import AppKit
import DoxCore

/// The complete body of a dock: glass (or solid) base, tint / gradient wash,
/// a soft inner top highlight, hairline border and a two-layer drop shadow.
///
/// Layer order (bottom → top):
/// 1. shadow (ambient + contact), masked so it never darkens through translucent glass
/// 2. base: system material, solid tint, or nothing (`.clear`)
/// 3. tint wash at `tintOpacity` (gradient along the dock axis when `gradientEnd` is set)
///    – layers 2 + 3 together at `backgroundOpacity`
/// 4. inner top highlight ("lit edge")
/// 5. border stroke
struct DockBackground: View {
    let appearance: DockAppearance
    let edge: DockEdge
    @Environment(\.colorScheme) private var environmentScheme

    /// Previews inside the settings window pass `.withinWindow` so the glass blurs
    /// the preview backdrop instead of the desktop.
    let blendingMode: NSVisualEffectView.BlendingMode

    init(appearance: DockAppearance, edge: DockEdge) {
        self.init(appearance: appearance, edge: edge, blendingMode: .behindWindow)
    }

    init(appearance: DockAppearance, edge: DockEdge, blendingMode: NSVisualEffectView.BlendingMode) {
        self.appearance = appearance
        self.edge = edge
        self.blendingMode = blendingMode
    }

    var body: some View {
        GeometryReader { geo in
            let radius = effectiveRadius(for: geo.size)
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            ZStack {
                shadowLayer(shape: shape)
                ZStack {
                    baseLayer(radius: radius)
                    tintLayer
                }
                .opacity(appearance.backgroundOpacity)
                .clipShape(shape)
                highlightLayer(shape: shape)
                if appearance.borderWidth > 0 {
                    shape.strokeBorder(Color(appearance.borderColor), lineWidth: appearance.borderWidth)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Layers

    private func effectiveRadius(for size: CGSize) -> CGFloat {
        let limit = max(0, min(size.width, size.height) / 2)
        return min(CGFloat(appearance.cornerRadius), limit)
    }

    @ViewBuilder
    private func baseLayer(radius: CGFloat) -> some View {
        switch appearance.material {
        case .solid:
            Color(appearance.tint.withAlpha(1))
        case .clear:
            Color.clear
        default:
            VisualEffectBackground(material: appearance.material, mode: appearance.mode,
                                   cornerRadius: radius, blendingMode: blendingMode)
        }
    }

    @ViewBuilder
    private var tintLayer: some View {
        if let end = appearance.gradientEnd {
            LinearGradient(colors: [Color(appearance.tint), Color(end)],
                           startPoint: edge.isVertical ? .top : .leading,
                           endPoint: edge.isVertical ? .bottom : .trailing)
                .opacity(appearance.tintOpacity)
        } else {
            Color(appearance.tint).opacity(appearance.tintOpacity)
        }
    }

    /// Light catching the upper rim plus a faint sheen; stronger on dark docks,
    /// subtle on light ones so it never looks like a bevel.
    private func highlightLayer(shape: RoundedRectangle) -> some View {
        let dark = isDarkLook
        let rim = (dark ? 0.22 : 0.55) * appearance.backgroundOpacity
        let sheen = (dark ? 0.07 : 0.18) * appearance.backgroundOpacity
        return ZStack {
            shape
                .fill(LinearGradient(colors: [Color.white.opacity(sheen), Color.white.opacity(0)],
                                     startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45)))
            shape
                .inset(by: 0.5)
                .stroke(LinearGradient(colors: [Color.white.opacity(rim), Color.white.opacity(0)],
                                       startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35)),
                        lineWidth: 1)
        }
        .clipShape(shape)
    }

    /// Ambient shadow + tight contact shadow, cut out of the body area.
    @ViewBuilder
    private func shadowLayer(shape: RoundedRectangle) -> some View {
        let r = CGFloat(appearance.shadowRadius)
        let o = appearance.shadowOpacity
        if o > 0 && r > 0 {
            let spill = r * 3 + 8
            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(o * 0.55), radius: min(2, r / 4), x: 0, y: 1)
                .shadow(color: .black.opacity(o), radius: r, x: 0, y: r * 0.3)
                .mask(
                    Rectangle()
                        .padding(-spill)
                        .overlay(shape.fill(Color.black).blendMode(.destinationOut))
                        .compositingGroup()
                )
        }
    }

    private var isDarkLook: Bool {
        switch appearance.mode {
        case .dark: return true
        case .light: return false
        case .system:
            if appearance.material == .solid || appearance.tintOpacity > 0.5 {
                return appearance.tint.luminance < 0.5
            }
            return environmentScheme == .dark
        }
    }
}
