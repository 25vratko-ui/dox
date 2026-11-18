import SwiftUI
import AppKit
import DoxCore

/// Detail page of one dock: header, live preview, tab bar, tab content.
@MainActor
struct DockDetailView: View {
    let dockID: UUID

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        @Bindable var router = SettingsRouter.shared
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.l) {
                DockDetailHeader(dockID: dockID)
                DockPreviewCanvas(dockID: dockID)
                    .frame(height: 210)
                DockTabBar(selection: $router.dockTab)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.m)

            Divider()

            Group {
                switch router.dockTab {
                case .content:
                    DockContentTab(dockID: dockID)
                case .appearance:
                    DockAppearanceTab(dockID: dockID)
                case .layout:
                    DockLayoutTab(dockID: dockID)
                case .behavior:
                    DockBehaviorTab(dockID: dockID)
                case .shortcut:
                    DockShortcutTab(dockID: dockID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.18), value: router.dockTab)
        }
    }
}

// MARK: - Header

@MainActor
private struct DockDetailHeader: View {
    let dockID: UUID

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        if let dock = store.dock(dockID) {
            HStack(spacing: DS.Spacing.m) {
                Image(systemName: dock.edge.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .fill(LinearGradient(colors: [Color(dock.appearance.accent),
                                                          Color(dock.appearance.accent).opacity(0.7)],
                                                 startPoint: .top, endPoint: .bottom))
                    )
                    .shadow(color: Color(dock.appearance.accent).opacity(0.35), radius: 8, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Názov docku", text: store.binding(dock: dockID, \.name))
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("\(dock.edge.displayName) · \(dock.layout.displayName) · \(SK.plural(dock.visibleTileCount, "ikona", "ikony", "ikon"))")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryText)
                }

                Spacer()

                Button {
                    DockManager.shared.toggle(dockID: dockID)
                } label: {
                    Label(DockManager.shared.isDockShown(dockID) ? "Skryť" : "Zobraziť",
                          systemImage: DockManager.shared.isDockShown(dockID) ? "eye.slash" : "eye")
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(!dock.isEnabled)
                .help("Dočasne zobrazí alebo skryje dock")

                Toggle(isOn: store.binding(dock: dockID, \.isEnabled)) {
                    Text(dock.isEnabled ? "Zapnutý" : "Vypnutý")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryText)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Tab bar

@MainActor
struct DockTabBar: View {
    @Binding var selection: DockSettingsTab
    @Namespace private var pill
    @State private var hovered: DockSettingsTab?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DockSettingsTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { selection = tab }
                } label: {
                    Label(tab.title, systemImage: tab.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selection == tab ? AnyShapeStyle(DS.Color.accent) : AnyShapeStyle(.secondary))
                        .background {
                            if selection == tab {
                                Capsule(style: .continuous)
                                    .fill(DS.Color.accent.opacity(0.16))
                                    .overlay(Capsule(style: .continuous)
                                        .strokeBorder(DS.Color.accent.opacity(0.3), lineWidth: 0.75))
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            } else if hovered == tab {
                                Capsule(style: .continuous).fill(Color.primary.opacity(0.05))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { h in hovered = h ? tab : (hovered == tab ? nil : hovered) }
            }
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(DS.Color.cardBackground))
        .overlay(Capsule(style: .continuous).strokeBorder(DS.Color.cardBorder, lineWidth: 1))
        .animation(DS.Motion.snappy, value: hovered)
    }
}

// MARK: - Live preview

private struct PreviewSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let n = nextValue()
        if n != .zero { value = n }
    }
}

/// The real dock view rendered on a wallpaper-like canvas, scaled to fit.
@MainActor
struct DockPreviewCanvas: View {
    let dockID: UUID

    @State private var contentSize: CGSize = .zero

    var body: some View {
        let dock = DoxStore.shared.dock(dockID)
        let edge = dock?.edge ?? .bottom
        let sizeBinding = $contentSize
        GeometryReader { geo in
            let inset: CGFloat = 16
            let available = CGSize(width: max(1, geo.size.width - inset * 2),
                                   height: max(1, geo.size.height - inset * 2))
            let scale: CGFloat = (contentSize.width > 0 && contentSize.height > 0)
                ? min(1, available.width / contentSize.width, available.height / contentSize.height)
                : 1
            DockRootView(dockID: dockID, isPreview: true)
                .fixedSize()
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: PreviewSizeKey.self, value: g.size)
                    }
                )
                .scaleEffect(scale)
                .frame(width: contentSize.width * scale, height: contentSize.height * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge.bodyAlignment)
                .padding(inset)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: edge)
        }
        .onPreferenceChange(PreviewSizeKey.self) { value in
            sizeBinding.wrappedValue = value
        }
        .background(PreviewWallpaper())
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l + 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l + 4, style: .continuous)
                .strokeBorder(DS.Color.cardBorder, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Label("Živý náhľad", systemImage: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.25)))
                .padding(10)
                .allowsHitTesting(false)
        }
        .overlay {
            if let dock, !dock.isEnabled {
                Text("Dock je vypnutý")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .allowsHitTesting(false)
            }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

/// Abstract "desktop" backdrop for previews: deep gradient with soft color blooms.
struct PreviewWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.13, blue: 0.27),
                                    Color(red: 0.20, green: 0.16, blue: 0.36),
                                    Color(red: 0.10, green: 0.30, blue: 0.38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 0.98, green: 0.55, blue: 0.45).opacity(0.55), .clear],
                           center: UnitPoint(x: 0.82, y: 0.2), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [Color(red: 0.36, green: 0.85, blue: 0.78).opacity(0.4), .clear],
                           center: UnitPoint(x: 0.15, y: 0.85), startRadius: 0, endRadius: 240)
            RadialGradient(colors: [Color(red: 0.55, green: 0.5, blue: 1).opacity(0.35), .clear],
                           center: UnitPoint(x: 0.45, y: 0.45), startRadius: 0, endRadius: 200)
        }
    }
}
