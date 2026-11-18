import SwiftUI
import AppKit
import DoxCore

// MARK: - Icon building blocks

/// A colored tile with a white SF Symbol – used for links, custom symbols and stack categories.
@MainActor
struct DockSymbolTile: View {
    let symbol: String
    let tint: RGBAColor
    let size: CGFloat
    var circle: Bool = false

    var body: some View {
        Group {
            if circle {
                tile(Circle())
            } else {
                tile(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            }
        }
        .frame(width: size, height: size)
    }

    private func tile<S: InsettableShape>(_ shape: S) -> some View {
        let base = Color(tint)
        return ZStack {
            shape.fill(LinearGradient(colors: [base.opacity(0.82), base],
                                      startPoint: .top, endPoint: .bottom))
            shape.fill(LinearGradient(colors: [Color.white.opacity(0.30), Color.white.opacity(0)],
                                      startPoint: .top, endPoint: .center))
            shape.strokeBorder(Color.white.opacity(0.22), lineWidth: max(0.5, size * 0.012))
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 0.5)
        }
    }
}

/// The icon of a dock item, honoring custom symbols, tint and the dock's icon shape.
@MainActor
struct DockItemIcon: View {
    let item: DockItem
    let size: CGFloat
    var shape: IconShape = .original
    var shadow: Bool = false
    /// Tint for symbol tiles when the item has none (usually the category color).
    var fallbackTint: RGBAColor = RGBAColor(hex: "#7C8CFF") ?? .white
    /// Requests a larger bitmap so magnified icons stay crisp.
    var renderScale: CGFloat = 1

    var body: some View {
        Group {
            if let symbol = symbolName {
                DockSymbolTile(symbol: symbol, tint: item.tint ?? fallbackTint, size: size, circle: shape == .circle)
            } else {
                shaped(
                    Image(nsImage: IconProvider.shared.icon(for: item, size: size * max(1, renderScale)))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(shadow ? 0.32 : 0), radius: size * 0.07, x: 0, y: size * 0.035)
    }

    private var symbolName: String? {
        if let s = item.customSymbol, !s.isEmpty { return s }
        if case .link = item.kind { return "globe" }
        return nil
    }

    @ViewBuilder
    private func shaped(_ image: some View) -> some View {
        switch shape {
        case .original:
            image
        case .squircle:
            let r = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            image
                .padding(size * 0.13)
                .background(.regularMaterial, in: r)
                .overlay(r.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                .clipShape(r)
        case .circle:
            image
                .padding(size * 0.16)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                .clipShape(Circle())
        }
    }
}

/// Premium floating capsule label shown on the side away from the screen edge.
@MainActor
struct DockLabelBubble: View {
    let text: String
    let fontSize: Double
    var dot: RGBAColor? = nil
    /// Compact labels (always-on, horizontal docks) are width-limited and lighter.
    var maxWidth: CGFloat? = nil

    var body: some View {
        HStack(spacing: fontSize * 0.45) {
            if let dot {
                Circle()
                    .fill(Color(dot))
                    .frame(width: fontSize * 0.5, height: fontSize * 0.5)
            }
            Text(text)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, fontSize * 0.8)
        .padding(.vertical, fontSize * 0.36)
        .frame(maxWidth: maxWidth)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 3)
        .fixedSize(horizontal: maxWidth == nil, vertical: true)
        .allowsHitTesting(false)
    }
}

/// Running-app marker drawn between the icon and the screen edge.
@MainActor
struct RunningIndicatorView: View {
    let style: RunningIndicator
    let isActive: Bool
    let accent: Color
    let vertical: Bool
    let size: CGFloat

    var body: some View {
        let color = isActive ? accent : Color.primary.opacity(0.72)
        switch style {
        case .none:
            EmptyView()
        case .dot:
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.6), radius: 2)
        case .bar:
            Capsule()
                .fill(color)
                .axisFrame(along: size * (isActive ? 0.42 : 0.26), cross: 3, vertical: vertical)
        case .glow:
            Capsule()
                .fill(accent)
                .axisFrame(along: size * 0.55, cross: 5, vertical: vertical)
                .blur(radius: 3)
                .opacity(isActive ? 1 : 0.65)
        }
    }
}

// MARK: - Shared tile chrome

/// Positioning shared by every tile: effect offsets, animation, resting slot, z-order.
struct DockTileChrome: ViewModifier {
    let slot: DockSlot
    let line: Int
    let magnifies: Bool
    let effect: TileEffect
    let edge: DockEdge
    let appearance: DockAppearance

    func body(content: Content) -> some View {
        let size = CGFloat(appearance.iconSize)
        let lift = edge.awayOffset(effect.lift)
        let offset = edge.isVertical
            ? CGSize(width: lift.width, height: effect.shift + lift.height)
            : CGSize(width: effect.shift + lift.width, height: lift.height)
        return content
            .offset(offset)
            .animation(DockMotion.hover(appearance), value: effect)
            .frame(width: size, height: size)
            .dockSlot(slot, line: line, magnifies: magnifies)
            .zIndex(effect.isHovered ? 3 : (effect.scale > 1.01 ? 1 : 0))
    }
}

// MARK: - Item tile

@MainActor
struct DockTileView: View {
    let dockID: UUID
    let dock: DockConfig
    let item: DockItem
    let category: DockCategory
    let index: Int
    let line: Int
    let effect: TileEffect
    /// Grid layout: tints the tile background with its category color.
    var showsCategoryTint: Bool = false
    let isPreview: Bool

    @State private var showFolder = false
    @State private var pressed = false
    @State private var insertTargeted = false

    private var a: DockAppearance { dock.appearance }
    private var edge: DockEdge { dock.edge }
    private var size: CGFloat { CGFloat(a.iconSize) }

    var body: some View {
        content
            .modifier(DockTileChrome(slot: .item(item.id), line: line, magnifies: !item.kind.isDecorative,
                                     effect: effect, edge: edge, appearance: a))
            .overlay(alignment: edge.isVertical ? .top : .leading) { insertionCaret }
            .contentShape(Rectangle())
            .onTapGesture { activate() }
            .contextMenu {
                DockItemMenu(dockID: dockID, dock: dock, item: item, categoryID: category.id, isPreview: isPreview)
            }
            .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
            .onDrop(of: DockDropHandler.acceptedTypes, isTargeted: $insertTargeted) { providers in
                DockDropHandler.handle(providers, dockID: dockID, categoryID: category.id, index: index)
            }
            .popover(isPresented: $showFolder, arrowEdge: edge.awayEdge) {
                FolderStackView(item: item, dockID: dockID, behavior: dock.behavior, edge: edge,
                                accent: a.accent, isPresented: $showFolder)
            }
            .onChange(of: showFolder) { _, open in setInteractionLock(open) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(item.displayTitle))
            .accessibilityAddTraits(.isButton)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .separator:
            Capsule()
                .fill(Color.primary.opacity(0.22))
                .axisFrame(along: 1.5, cross: size * 0.62, vertical: edge.isVertical)
                .frame(width: size, height: size)
        case .spacer:
            Color.clear.frame(width: size, height: size)
        default:
            iconStack
        }
    }

    private var iconStack: some View {
        DockItemIcon(item: item, size: size, shape: a.iconShape, shadow: a.iconShadow,
                     fallbackTint: category.color, renderScale: CGFloat(max(1, a.magnification)))
            .background {
                if showsCategoryTint {
                    RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                        .fill(Color(category.color).opacity(0.16))
                        .padding(-3)
                }
            }
            .scaleEffect(effect.scale * (pressed ? 0.86 : 1), anchor: edge.towardAnchor)
            .shadow(color: Color(a.accent).opacity(effect.glow ? 0.85 : 0), radius: effect.glow ? size * 0.28 : 0)
            .shadow(color: Color(a.accent).opacity(isRunning && a.runningIndicator == .glow ? 0.45 : 0),
                    radius: size * 0.16)
            .overlay(alignment: edge.towardAlignment) {
                if isRunning {
                    RunningIndicatorView(style: a.runningIndicator, isActive: isActive, accent: Color(a.accent),
                                         vertical: edge.isVertical, size: size)
                        .offset(edge.awayOffset(-max(2, CGFloat(a.padding) / 2)))
                }
            }
            .overlay(alignment: edge.awayAlignment) { label }
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var label: some View {
        if showsLabel {
            let compact = a.labelMode == .always && !edge.isVertical
            DockLabelBubble(text: item.displayTitle, fontSize: a.labelFontSize,
                            dot: compact ? nil : category.color,
                            maxWidth: compact ? size + CGFloat(a.iconSpacing) : nil)
                .modifier(AwayPlacement(edge: edge, gap: 6 + (effect.scale - 1) * size))
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: edge.towardAnchor)))
        }
    }

    @ViewBuilder
    private var insertionCaret: some View {
        if insertTargeted {
            Capsule()
                .fill(Color(a.accent))
                .axisFrame(along: 3, cross: size * 0.8, vertical: edge.isVertical)
                .offset(x: edge.isVertical ? 0 : -CGFloat(a.iconSpacing) / 2 - 1.5,
                        y: edge.isVertical ? -CGFloat(a.iconSpacing) / 2 - 1.5 : 0)
                .shadow(color: Color(a.accent).opacity(0.6), radius: 4)
                .transition(.opacity)
        }
    }

    // MARK: State

    private var showsLabel: Bool {
        guard !item.kind.isDecorative, !showFolder else { return false }
        switch a.labelMode {
        case .never: return false
        case .always: return true
        case .onHover: return effect.isHovered
        }
    }

    private var isRunning: Bool {
        guard dock.behavior.showRunningApps, a.runningIndicator != .none else { return false }
        guard case .app = item.kind else { return false }
        return RunningAppsMonitor.shared.isRunning(item)
    }

    private var isActive: Bool {
        guard case .app = item.kind else { return false }
        return RunningAppsMonitor.shared.isActive(item)
    }

    // MARK: Actions

    private func activate() {
        guard !isPreview else { return }
        let alternate = NSEvent.modifierFlags.contains(.option)
        switch item.kind {
        case .separator, .spacer:
            return
        case .folder where !alternate:
            showFolder = true
        default:
            ItemLauncher.open(item, behavior: dock.behavior, alternate: alternate)
            pulse()
        }
    }

    private func pulse() {
        guard a.animationSpeed > 0.01 else { return }
        let speed = a.animationSpeed
        withAnimation(.spring(response: 0.16 * speed, dampingFraction: 0.55)) { pressed = true }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(150_000_000 * speed))
            withAnimation(.spring(response: 0.3 * speed, dampingFraction: 0.5)) { pressed = false }
        }
    }

    private func setInteractionLock(_ locked: Bool) {
        guard !isPreview else { return }
        DockManager.shared.setInteractionLock(dockID: dockID, locked: locked)
    }
}

// MARK: - Stack tile (collapsed category)

@MainActor
struct DockStackTile: View {
    let dockID: UUID
    let dock: DockConfig
    let category: DockCategory
    let line: Int
    let effect: TileEffect
    let isPreview: Bool

    @State private var showStack = false
    @State private var pressed = false

    private var a: DockAppearance { dock.appearance }
    private var edge: DockEdge { dock.edge }
    private var size: CGFloat { CGFloat(a.iconSize) }

    var body: some View {
        tile
            .modifier(DockTileChrome(slot: .stack(category.id), line: line, magnifies: true,
                                     effect: effect, edge: edge, appearance: a))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isPreview else { return }
                showStack = true
            }
            .contextMenu { menu }
            .popover(isPresented: $showStack, arrowEdge: edge.awayEdge) {
                CategoryStackPopover(dockID: dockID, dock: dock, category: category,
                                     isPreview: isPreview, isPresented: $showStack)
            }
            .onChange(of: showStack) { _, open in
                guard !isPreview else { return }
                DockManager.shared.setInteractionLock(dockID: dockID, locked: open)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(category.name))
            .accessibilityAddTraits(.isButton)
    }

    private var tile: some View {
        ZStack {
            // Two "cards" peeking out behind the main tile hint at a stack.
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Color(category.color).opacity(0.35))
                .frame(width: size * 0.84, height: size * 0.84)
                .rotationEffect(.degrees(showStack ? -14 : -8))
                .offset(edge.awayOffset(size * 0.05))
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Color(category.color).opacity(0.55))
                .frame(width: size * 0.9, height: size * 0.9)
                .rotationEffect(.degrees(showStack ? 9 : 5))
            DockSymbolTile(symbol: category.symbol, tint: category.color, size: size * 0.92,
                           circle: a.iconShape == .circle)
                .overlay(alignment: .topTrailing) {
                    Text("\(category.items.filter { !$0.kind.isDecorative }.count)")
                        .font(.system(size: max(9, size * 0.2), weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, size * 0.08)
                        .frame(minWidth: size * 0.3, minHeight: size * 0.3)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                        .offset(x: size * 0.08, y: -size * 0.08)
                }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(a.iconShadow ? 0.3 : 0), radius: size * 0.07, x: 0, y: size * 0.035)
        .scaleEffect(effect.scale * (pressed ? 0.88 : 1), anchor: edge.towardAnchor)
        .shadow(color: Color(a.accent).opacity(effect.glow ? 0.85 : 0), radius: effect.glow ? size * 0.28 : 0)
        .animation(DockMotion.standard(a), value: showStack)
        .overlay(alignment: edge.awayAlignment) {
            if a.labelMode != .never && (a.labelMode == .always || effect.isHovered) && !showStack {
                DockLabelBubble(text: category.name, fontSize: a.labelFontSize, dot: category.color)
                    .modifier(AwayPlacement(edge: edge, gap: 6 + (effect.scale - 1) * size))
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: edge.towardAnchor)))
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button {
            SettingsRouter.shared.editCategory(category.id, dock: dockID)
        } label: {
            Label("Upraviť kategóriu…", systemImage: "slider.horizontal.3")
        }
        Button {
            DoxStore.shared.updateDock(dockID) { d in
                if let i = d.categoryIndex(category.id) { d.categories[i].display = .inline }
            }
        } label: {
            Label("Rozbaliť do docku", systemImage: "rectangle.expand.vertical")
        }
        Divider()
        Button {
            DoxStore.shared.updateDock(dockID) { d in
                if let i = d.categoryIndex(category.id) { d.categories[i].isHidden = true }
            }
        } label: {
            Label("Skryť kategóriu", systemImage: "eye.slash")
        }
    }
}

// MARK: - Context menu

@MainActor
struct DockItemMenu: View {
    let dockID: UUID
    let dock: DockConfig
    let item: DockItem
    let categoryID: UUID
    let isPreview: Bool

    var body: some View {
        if !item.kind.isDecorative {
            Button {
                guard !isPreview else { return }
                ItemLauncher.open(item, behavior: dock.behavior, alternate: false)
            } label: {
                Label("Otvoriť", systemImage: "arrow.up.forward.app")
            }
            if item.kind.path != nil {
                Button {
                    ItemLauncher.revealInFinder(item)
                } label: {
                    Label("Ukázať vo Finderi", systemImage: "folder")
                }
            }
            Divider()
        }
        Button {
            SettingsRouter.shared.editItem(item.id, category: categoryID, dock: dockID)
        } label: {
            Label("Upraviť…", systemImage: "slider.horizontal.3")
        }
        if dock.categories.count > 1 {
            Menu {
                ForEach(dock.categories) { c in
                    Button {
                        DoxStore.shared.updateDock(dockID) { d in
                            let count = d.categories.first { $0.id == c.id }?.items.count ?? 0
                            d.moveItem(item.id, toCategory: c.id, at: count)
                        }
                    } label: {
                        Label(c.name, systemImage: c.symbol)
                    }
                    .disabled(c.id == categoryID)
                }
            } label: {
                Label("Presunúť do", systemImage: "arrow.right.circle")
            }
        }
        Divider()
        Button(role: .destructive) {
            DoxStore.shared.updateDock(dockID) { $0.removeItem(item.id) }
        } label: {
            Label("Odstrániť z docku", systemImage: "trash")
        }
    }
}
