import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DoxCore

/// The whole dock: background + categories laid out per `DockConfig.layout`.
///
/// Sizes itself to the dock **body** only (resting size from
/// `DockGeometry.restingSize(for:headerExtent: DockPanelLayout.headerExtent(for:))`).
/// The hosting panel pins it to the screen edge; magnified tiles and labels overflow
/// into the panel's headroom on the side away from the edge.
@MainActor
struct DockRootView: View {
    let dockID: UUID
    let screenID: String?
    let isPreview: Bool

    init(dockID: UUID, screenID: String? = nil, isPreview: Bool = false) {
        self.dockID = dockID
        self.screenID = screenID
        self.isPreview = isPreview
    }

    @State private var pointer: CGPoint?
    @State private var slots: [DockSlot: DockSlotInfo] = [:]

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        if let dock = store.dock(dockID) {
            dockView(dock)
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    // MARK: Root

    private func dockView(_ dock: DockConfig) -> some View {
        let a = dock.appearance
        let effects = DockMagnifier.effects(pointer: pointer, slots: slots, appearance: a,
                                            vertical: dock.edge.isVertical,
                                            multiLine: DockGeometry.lineCount(for: dock) > 1)
        let slotsBinding = $slots
        let pointerBinding = $pointer
        return dockBody(dock, effects: effects)
            // While hovering, the hit area grows into the headroom so magnified tiles stay "inside".
            .contentShape(DockHitShape(insets: pointer == nil ? EdgeInsets() : Self.hoverInsets(for: dock)))
            .onContinuousHover(coordinateSpace: .named(DockSpace.name)) { phase in
                switch phase {
                case .active(let p):
                    pointerBinding.wrappedValue = p
                case .ended:
                    pointerBinding.wrappedValue = nil
                }
            }
            .coordinateSpace(.named(DockSpace.name))
            .onPreferenceChange(DockSlotFrameKey.self) { value in
                slotsBinding.wrappedValue = value
            }
            .onChange(of: dock.layout) { _, _ in pointerBinding.wrappedValue = nil }
            .modifier(DockColorSchemeModifier(mode: a.mode))
    }

    @ViewBuilder
    private func dockBody(_ dock: DockConfig, effects: [DockSlot: TileEffect]) -> some View {
        let a = dock.appearance
        let cats = dock.visibleCategories
        Group {
            if dock.visibleTileCount == 0 {
                DockEmptyState(dockID: dockID, edge: dock.edge, appearance: a,
                               categoryID: cats.first?.id, isPreview: isPreview)
            } else {
                switch dock.layout {
                case .line:
                    lineLayout(dock, cats: cats, effects: effects)
                case .grid:
                    gridLayout(dock, cats: cats, effects: effects)
                case .shelves:
                    shelvesLayout(dock, cats: cats, effects: effects)
                }
            }
        }
        .padding(CGFloat(a.padding))
        .background(
            DockBackground(appearance: a, edge: dock.edge,
                           blendingMode: isPreview ? .withinWindow : .behindWindow)
        )
        .contextMenu { backgroundMenu }
    }

    // MARK: Layouts

    /// One line across every visible category.
    private func lineLayout(_ dock: DockConfig, cats: [DockCategory], effects: [DockSlot: TileEffect]) -> some View {
        let a = dock.appearance
        let stack = dock.edge.isVertical
            ? AnyLayout(VStackLayout(spacing: CGFloat(a.categorySpacing)))
            : AnyLayout(HStackLayout(spacing: CGFloat(a.categorySpacing)))
        return stack {
            ForEach(Array(cats.enumerated()), id: \.element.id) { index, cat in
                DockCategoryGroup(dockID: dockID, dock: dock, category: cat, line: 0,
                                  showsDivider: index > 0, effects: effects, isPreview: isPreview)
            }
        }
    }

    /// One line (shelf) per category, stacked away from the edge.
    private func shelvesLayout(_ dock: DockConfig, cats: [DockCategory], effects: [DockSlot: TileEffect]) -> some View {
        let a = dock.appearance
        let stack = dock.edge.isVertical
            ? AnyLayout(HStackLayout(alignment: .top, spacing: CGFloat(a.categorySpacing)))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: CGFloat(a.categorySpacing)))
        return stack {
            ForEach(Array(cats.enumerated()), id: \.element.id) { index, cat in
                DockCategoryGroup(dockID: dockID, dock: dock, category: cat, line: index,
                                  showsDivider: false, effects: effects, isPreview: isPreview)
            }
        }
    }

    /// `gridLines` rows (horizontal docks) or columns (vertical docks); tiles keep a category tint.
    private func gridLayout(_ dock: DockConfig, cats: [DockCategory], effects: [DockSlot: TileEffect]) -> some View {
        let a = dock.appearance
        let vertical = dock.edge.isVertical
        let entries = Self.gridEntries(cats)
        let lines = max(1, DockGeometry.lineCount(for: dock))
        let perLine = max(1, Int((Double(entries.count) / Double(lines)).rounded(.up)))
        let chunks: [[DockGridEntry]] = stride(from: 0, to: entries.count, by: perLine).map {
            Array(entries[$0..<min($0 + perLine, entries.count)])
        }
        let spacing = CGFloat(a.iconSpacing)
        let cross = vertical
            ? AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
        let axis = vertical ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
        let tinted = a.categoryHeaderStyle != .hidden

        return cross {
            ForEach(Array(chunks.enumerated()), id: \.offset) { lineIndex, chunk in
                axis {
                    ForEach(chunk) { entry in
                        switch entry.kind {
                        case .item(let item, let category, let index):
                            DockTileView(dockID: dockID, dock: dock, item: item, category: category,
                                         index: index, line: lineIndex,
                                         effect: effects[.item(item.id)] ?? .rest,
                                         showsCategoryTint: tinted, isPreview: isPreview)
                        case .stack(let category):
                            DockStackTile(dockID: dockID, dock: dock, category: category, line: lineIndex,
                                          effect: effects[.stack(category.id)] ?? .rest, isPreview: isPreview)
                        }
                    }
                }
            }
        }
        .onDrop(of: DockDropHandler.acceptedTypes, isTargeted: nil) { providers in
            DockDropHandler.handle(providers, dockID: dockID, categoryID: cats.last?.id, index: nil)
        }
    }

    private static func gridEntries(_ cats: [DockCategory]) -> [DockGridEntry] {
        var out: [DockGridEntry] = []
        for cat in cats {
            if cat.display == .stack {
                out.append(DockGridEntry(id: .stack(cat.id), kind: .stack(cat)))
            } else {
                for (index, item) in cat.items.enumerated() {
                    out.append(DockGridEntry(id: .item(item.id), kind: .item(item, cat, index)))
                }
            }
        }
        return out
    }

    // MARK: Menus

    @ViewBuilder
    private var backgroundMenu: some View {
        Button {
            SettingsRouter.shared.openDock(dockID)
        } label: {
            Label("Nastavenia docku…", systemImage: "slider.horizontal.3")
        }
        Button {
            let category = DockCategory(name: "Nová kategória", symbol: "square.grid.2x2")
            store.updateDock(dockID) { $0.addCategory(category) }
            SettingsRouter.shared.editCategory(category.id, dock: dockID)
        } label: {
            Label("Pridať kategóriu…", systemImage: "plus.rectangle.on.rectangle")
        }
        if !isPreview {
            Divider()
            Button {
                DockManager.shared.setDockShown(dockID, false)
            } label: {
                Label("Skryť tento dock", systemImage: "eye.slash")
            }
        }
    }

    // MARK: Geometry helpers (shared with the panel / settings preview)

    /// Header extent along the dock axis, identical to what the panel uses for sizing.
    static func headerExtent(for dock: DockConfig) -> CGFloat {
        CGFloat(DockPanelLayout.headerExtent(for: dock))
    }

    /// Room needed beyond the body: away from the edge (magnification + labels) and at both ends.
    static func headroom(for dock: DockConfig) -> (away: CGFloat, along: CGFloat) {
        DockPanelLayout.headroom(for: dock)
    }

    /// Negative insets that extend the hover hit area into the magnification headroom.
    private static func hoverInsets(for dock: DockConfig) -> EdgeInsets {
        let room = headroom(for: dock)
        let away = -CGFloat(DockGeometry.magnificationHeadroom(for: dock.appearance)) - 4
        let along = -room.along
        switch dock.edge {
        case .left: return EdgeInsets(top: along, leading: 0, bottom: along, trailing: away)
        case .right: return EdgeInsets(top: along, leading: away, bottom: along, trailing: 0)
        case .top: return EdgeInsets(top: 0, leading: along, bottom: away, trailing: along)
        case .bottom: return EdgeInsets(top: away, leading: along, bottom: 0, trailing: along)
        }
    }
}

// MARK: - Grid entry

struct DockGridEntry: Identifiable {
    enum Kind {
        case item(DockItem, DockCategory, Int)
        case stack(DockCategory)
    }
    let id: DockSlot
    let kind: Kind
}

// MARK: - Category group

/// One category in a line / shelf: optional header, then its tiles (or a single stack tile).
/// Accepts drops (append) and shows a colored drop highlight.
@MainActor
struct DockCategoryGroup: View {
    let dockID: UUID
    let dock: DockConfig
    let category: DockCategory
    let line: Int
    let showsDivider: Bool
    let effects: [DockSlot: TileEffect]
    let isPreview: Bool

    @State private var isTargeted = false

    private var a: DockAppearance { dock.appearance }
    private var vertical: Bool { dock.edge.isVertical }
    private var style: CategoryHeaderStyle { a.categoryHeaderStyle }
    private var showsHeader: Bool { style == .pill || style == .label }

    var body: some View {
        let stack = vertical
            ? AnyLayout(VStackLayout(spacing: CGFloat(a.iconSpacing)))
            : AnyLayout(HStackLayout(spacing: CGFloat(a.iconSpacing)))
        stack {
            if showsHeader { header }
            if category.display == .stack {
                DockStackTile(dockID: dockID, dock: dock, category: category, line: line,
                              effect: effects[.stack(category.id)] ?? .rest, isPreview: isPreview)
            } else {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    DockTileView(dockID: dockID, dock: dock, item: item, category: category,
                                 index: index, line: line,
                                 effect: effects[.item(item.id)] ?? .rest, isPreview: isPreview)
                }
            }
        }
        .background { dropHighlight }
        .overlay(alignment: vertical ? .top : .leading) { divider }
        .zIndex(containsHover ? 1 : 0)
        .onDrop(of: DockDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            DockDropHandler.handle(providers, dockID: dockID, categoryID: category.id, index: nil)
        }
        .animation(DockMotion.standard(a), value: isTargeted)
    }

    private var containsHover: Bool {
        if effects[.stack(category.id)]?.isHovered == true { return true }
        return category.items.contains { effects[.item($0.id)]?.isHovered == true }
    }

    /// Shift of the group's first slot, so headers / dividers travel with magnified tiles.
    private var leadingShift: CGFloat {
        if showsHeader { return effects[.header(category.id)]?.shift ?? 0 }
        if category.display == .stack { return effects[.stack(category.id)]?.shift ?? 0 }
        guard let first = category.items.first else { return 0 }
        return effects[.item(first.id)]?.shift ?? 0
    }

    private var header: some View {
        let extent = max(0, DockRootView.headerExtent(for: dock) - CGFloat(a.iconSpacing))
        let shift = effects[.header(category.id)]?.shift ?? 0
        return CategoryBadge(name: category.name, symbol: category.symbol, color: category.color,
                             style: style, vertical: vertical)
            .axisFrame(along: extent, cross: CGFloat(a.iconSize), vertical: vertical)
            .offset(x: vertical ? 0 : shift, y: vertical ? shift : 0)
            .animation(DockMotion.hover(a), value: shift)
            .dockSlot(.header(category.id), line: line, magnifies: false)
            .help(category.name)
    }

    @ViewBuilder
    private var divider: some View {
        if showsDivider && style == .divider {
            let gap = CGFloat(a.categorySpacing)
            let shift = leadingShift
            CategoryBadge(name: category.name, symbol: category.symbol, color: category.color,
                          style: .divider, vertical: vertical)
                .axisFrame(along: 1, cross: CGFloat(a.iconSize), vertical: vertical)
                .offset(x: vertical ? 0 : shift - gap / 2, y: vertical ? shift - gap / 2 : 0)
                .animation(DockMotion.hover(a), value: shift)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var dropHighlight: some View {
        if isTargeted {
            RoundedRectangle(cornerRadius: max(6, CGFloat(a.cornerRadius) * 0.55), style: .continuous)
                .fill(Color(category.color).opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: max(6, CGFloat(a.cornerRadius) * 0.55), style: .continuous)
                        .strokeBorder(Color(category.color).opacity(0.8),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
                .padding(-4)
                .transition(.opacity)
        }
    }
}

// MARK: - Empty state

/// Friendly drop target shown when the dock has nothing to display.
/// In the real panel it is one tile big (the panel is sized for that); the settings preview shows the text inline.
@MainActor
struct DockEmptyState: View {
    let dockID: UUID
    let edge: DockEdge
    let appearance: DockAppearance
    let categoryID: UUID?
    let isPreview: Bool

    @State private var isTargeted = false
    @State private var hovering = false

    static let message = "Pretiahni sem aplikácie, priečinky alebo odkazy"

    private var size: CGFloat { CGFloat(appearance.iconSize) }
    private var accent: Color { Color(appearance.accent) }

    var body: some View {
        Group {
            if isPreview {
                let stack = edge.isVertical
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 12))
                stack {
                    tile
                    Text(Self.message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: edge.isVertical ? 140 : 220)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                tile
                    .overlay(alignment: edge.awayAlignment) {
                        if hovering || isTargeted {
                            DockLabelBubble(text: Self.message, fontSize: appearance.labelFontSize)
                                .modifier(AwayPlacement(edge: edge, gap: 8))
                                .transition(.opacity)
                        }
                    }
            }
        }
        .contentShape(Rectangle())
        .onHover { h in hovering = h }
        .onDrop(of: DockDropHandler.acceptedTypes, isTargeted: $isTargeted) { providers in
            DockDropHandler.handle(providers, dockID: dockID, categoryID: categoryID, index: nil)
        }
        .animation(DockMotion.standard(appearance), value: isTargeted)
        .animation(DockMotion.standard(appearance), value: hovering)
        .help(Self.message)
    }

    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(accent.opacity(isTargeted ? 0.22 : 0.08))
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .strokeBorder(accent.opacity(isTargeted ? 1 : 0.55),
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            Image(systemName: isTargeted ? "plus" : "tray.and.arrow.down.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
        .scaleEffect(isTargeted ? 1.08 : 1)
    }
}
