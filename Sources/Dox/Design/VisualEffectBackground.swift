import SwiftUI
import AppKit
import DoxCore

/// Behind-window blur backed by `NSVisualEffectView`.
/// For `.solid` / `.clear` (no system material) the view stays fully transparent;
/// `DockBackground` draws those modes itself.
struct VisualEffectBackground: NSViewRepresentable {
    let material: DockMaterial
    let mode: AppearanceMode
    /// Optional rounded mask applied at the AppKit level. Behind-window blending
    /// is composited by the window server, so a mask image keeps corners crisp
    /// even where a SwiftUI clip alone would not.
    let cornerRadius: CGFloat
    /// `.behindWindow` for real docks; `.withinWindow` for previews inside the settings window.
    let blendingMode: NSVisualEffectView.BlendingMode

    init(material: DockMaterial, mode: AppearanceMode) {
        self.init(material: material, mode: mode, cornerRadius: 0)
    }

    init(material: DockMaterial, mode: AppearanceMode, cornerRadius: CGFloat,
         blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.mode = mode
        self.cornerRadius = max(0, cornerRadius)
        self.blendingMode = blendingMode
    }

    final class Coordinator {
        var maskRadius: CGFloat = -1
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        configure(view, context: context)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        configure(view, context: context)
    }

    private func configure(_ view: NSVisualEffectView, context: Context) {
        if let ns = material.nsMaterial {
            if view.material != ns { view.material = ns }
            view.alphaValue = 1
        } else {
            view.alphaValue = 0
        }
        view.appearance = mode.nsAppearance
        if view.blendingMode != blendingMode { view.blendingMode = blendingMode }
        if view.state != .active { view.state = .active }

        if context.coordinator.maskRadius != cornerRadius {
            context.coordinator.maskRadius = cornerRadius
            view.maskImage = cornerRadius > 0 ? Self.maskImage(cornerRadius: cornerRadius) : nil
        }
    }

    /// Stretchable rounded-rect mask (9-slice via cap insets).
    static func maskImage(cornerRadius r: CGFloat) -> NSImage {
        let edge = 2 * r + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
        image.resizingMode = .stretch
        return image
    }
}
