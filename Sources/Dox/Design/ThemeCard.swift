import SwiftUI
import AppKit
import DoxCore

/// Gallery tile for a theme: a miniature dock on a small "wallpaper",
/// the theme name below and an accent ring when selected.
struct ThemeCard: View {
    let theme: ThemePreset
    let isSelected: Bool
    @State private var hovering = false
    @Environment(\.colorScheme) private var systemScheme

    init(theme: ThemePreset, isSelected: Bool) {
        self.theme = theme
        self.isSelected = isSelected
    }

    private var scheme: ColorScheme { theme.appearance.mode.colorScheme ?? systemScheme }

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            ZStack {
                wallpaper
                miniDock
            }
            .frame(width: 148, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(DS.Color.cardBorder, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m + 3, style: .continuous)
                    .strokeBorder(DS.Color.accent, lineWidth: 2)
                    .padding(-3)
                    .opacity(isSelected ? 1 : 0)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, DS.Color.accent)
                        .padding(5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(hovering && !isSelected ? 1.025 : 1)

            HStack(spacing: DS.Spacing.xs) {
                Text(theme.name)
                    .font(DS.Font.caption.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : DS.Color.secondaryText)
                    .lineLimit(1)
                if !theme.isBuiltIn {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Color.secondaryText)
                        .help("Vlastná téma")
                }
            }
        }
        .padding(DS.Spacing.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(DS.Motion.snappy, value: hovering)
        .animation(DS.Motion.snappy, value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Téma \(theme.name)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Soft abstract backdrop so translucent themes have something to blur.
    private var wallpaper: some View {
        let accent = theme.appearance.accent
        let colors: [Color]
        if scheme == .dark {
            colors = [Color(RGBAColor(hex: "#1B1F3A")!), Color(accent.mixed(with: .black, amount: 0.55)),
                      Color(RGBAColor(hex: "#0C0D14")!)]
        } else {
            colors = [Color(RGBAColor(hex: "#DCE6F7")!), Color(accent.mixed(with: .white, amount: 0.7)),
                      Color(RGBAColor(hex: "#F4EFE8")!)]
        }
        return ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color(accent).opacity(scheme == .dark ? 0.35 : 0.25))
                .frame(width: 70, height: 70)
                .blur(radius: 18)
                .offset(x: -38, y: -18)
        }
    }

    private var miniAppearance: DockAppearance {
        var a = theme.appearance
        a.cornerRadius = min(a.cornerRadius * 0.45, 12)
        a.shadowRadius = a.shadowRadius * 0.3
        a.borderWidth = min(a.borderWidth, 1)
        return a
    }

    private var miniDock: some View {
        let accent = theme.appearance.accent
        let shades: [RGBAColor] = [
            accent,
            accent.mixed(with: .white, amount: 0.35),
            accent.mixed(with: .black, amount: 0.3),
            accent.mixed(with: .white, amount: 0.6),
        ]
        let tileRadius: CGFloat = theme.appearance.iconShape == .circle ? 9 : 5
        return HStack(spacing: 5) {
            ForEach(shades.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                    .fill(LinearGradient(colors: [Color(shades[i]), Color(shades[i].mixed(with: .black, amount: 0.18))],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(DockBackground(appearance: miniAppearance, edge: .bottom, blendingMode: .withinWindow))
        .environment(\.colorScheme, scheme)
        .offset(y: 14)
    }
}
