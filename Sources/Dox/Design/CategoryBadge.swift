import SwiftUI
import DoxCore

/// In-dock category header, rendered per `CategoryHeaderStyle`.
/// `vertical` is true for left/right docks (items flow top → bottom, header sits above a group);
/// false for top/bottom docks (header sits before a group, to its leading side).
struct CategoryBadge: View {
    let name: String
    let symbol: String
    let color: RGBAColor
    let style: CategoryHeaderStyle
    let vertical: Bool

    init(name: String, symbol: String, color: RGBAColor, style: CategoryHeaderStyle, vertical: Bool) {
        self.name = name
        self.symbol = symbol
        self.color = color
        self.style = style
        self.vertical = vertical
    }

    var body: some View {
        switch style {
        case .hidden:
            EmptyView()
        case .divider:
            divider
        case .pill:
            pill
        case .label:
            label
        }
    }

    // MARK: Divider – hairline across the dock, fading at both ends

    private var divider: some View {
        let fade = LinearGradient(
            stops: [
                .init(color: Color.primary.opacity(0), location: 0),
                .init(color: Color.primary.opacity(0.22), location: 0.2),
                .init(color: Color.primary.opacity(0.22), location: 0.8),
                .init(color: Color.primary.opacity(0), location: 1),
            ],
            startPoint: vertical ? .leading : .top,
            endPoint: vertical ? .trailing : .bottom)
        return Rectangle()
            .fill(fade)
            .frame(width: vertical ? nil : 1, height: vertical ? 1 : nil)
            .frame(maxWidth: vertical ? CGFloat.infinity : nil, maxHeight: vertical ? nil : CGFloat.infinity)
            .padding(vertical ? .horizontal : .vertical, 6)
            .accessibilityLabel(name)
    }

    // MARK: Pill – compact capsule tinted with the category color

    private var pill: some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color(color))
            .frame(width: vertical ? 26 : 18, height: vertical ? 18 : 26)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(color).opacity(0.18))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color(color).opacity(0.4), lineWidth: 0.75)
            )
            .shadow(color: Color(color).opacity(0.25), radius: 4)
            .help(name)
            .accessibilityLabel(name)
    }

    // MARK: Label – symbol + name in small caps

    @ViewBuilder
    private var label: some View {
        let symbolView = Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(color))
        let text = Text(name)
            .font(.system(size: 10, weight: .semibold).smallCaps())
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        if vertical {
            HStack(spacing: 4) {
                symbolView
                text.truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 3) {
                symbolView
                text.fixedSize()
            }
            .padding(.horizontal, 2)
            .accessibilityElement(children: .combine)
        }
    }
}
