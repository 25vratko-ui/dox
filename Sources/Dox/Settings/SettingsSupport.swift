import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DoxCore

/// Generic labelled row matching the Design rows (fixed label column).
@MainActor
struct FieldRow<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            RowLabel(title: title)
            content
            Spacer(minLength: 0)
        }
        .frame(minHeight: DS.Layout.rowHeight)
    }
}

/// Small explanatory text under a group of rows.
@MainActor
struct SettingsCaption: View {
    let text: String
    var symbol: String? = nil

    init(_ text: String, symbol: String? = nil) {
        self.text = text
        self.symbol = symbol
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(DS.Font.caption)
        .foregroundStyle(DS.Color.secondaryText)
    }
}

/// Large page title used on top of every settings page.
@MainActor
struct SettingsPageHeader: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(LinearGradient(colors: [DS.Color.accent, DS.Color.accent.opacity(0.7)],
                                             startPoint: .top, endPoint: .bottom))
                )
                .shadow(color: DS.Color.accent.opacity(0.35), radius: 8, x: 0, y: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondaryText)
            }
            Spacer()
        }
    }
}

/// Scrollable page body with consistent padding and a readable max width.
@MainActor
struct SettingsScrollPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                content
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// Button style for secondary actions inside cards: soft fill, hover highlight.
struct SoftButtonStyle: ButtonStyle {
    var tint: Color = DS.Color.accent
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        SoftButtonBody(configuration: configuration, tint: destructive ? Color.red : tint)
    }

    private struct SoftButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(tint.opacity(configuration.isPressed ? 0.24 : (hovering ? 0.16 : 0.1)))
                )
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .animation(DS.Motion.snappy, value: hovering)
        }
    }
}

/// Open / save panels for JSON import & export.
@MainActor
enum JSONFilePanel {
    /// Asks for a destination and writes `data`. Returns false when cancelled.
    static func save(_ data: Data, suggestedName: String, message: String) throws -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        panel.message = message
        panel.prompt = "Exportovať"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try data.write(to: url, options: .atomic)
        return true
    }

    /// Asks for a JSON file and returns its contents, or nil when cancelled.
    static func open(message: String) throws -> Data? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = message
        panel.prompt = "Importovať"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try Data(contentsOf: url)
    }
}

/// Simple error alert payload.
struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension DisplayTarget {
    var displayName: String {
        switch self {
        case .main: "Hlavný displej"
        case .withMouse: "Displej s kurzorom"
        case .all: "Všetky displeje"
        case .named(let name): name
        }
    }
}
