import SwiftUI
import AppKit
import DoxCore

// MARK: - Section card

/// A titled card grouping related settings rows.
struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    let content: Content

    init(_ title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                            .fill(LinearGradient(colors: [DS.Color.accent, DS.Color.accent.opacity(0.75)],
                                                 startPoint: .top, endPoint: .bottom))
                    )
                Text(title)
                    .font(DS.Font.sectionTitle)
            }
            .padding(.leading, DS.Spacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                content
            }
            .padding(DS.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(DS.Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .strokeBorder(DS.Color.cardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Shared row pieces

/// Fixed-width leading label so every row's control starts on the same line.
struct RowLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(DS.Font.rowTitle)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: DS.Layout.labelWidth, alignment: .leading)
            .help(title)
    }
}

/// Monospaced value capsule (slider values, hex codes).
struct ValueReadout: View {
    let text: String
    var width: CGFloat? = DS.Layout.readoutWidth
    var body: some View {
        Text(text)
            .font(DS.Font.mono)
            .monospacedDigit()
            .foregroundStyle(DS.Color.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, DS.Spacing.s - 2)
            .padding(.vertical, 3)
            .frame(width: width, alignment: .trailing)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(DS.Color.readoutBackground)
            )
    }
}

// MARK: - Slider

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1, unit: String = "pt") {
        self.title = title
        self._value = value
        self.range = range
        // A percent slider operates on 0...1; an integer step would make it unusable.
        self.step = (unit == "%" && step >= 1) ? 0.01 : step
        self.unit = unit
    }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            RowLabel(title: title)
            slider
                .controlSize(.small)
            ValueReadout(text: formatted)
        }
        .frame(minHeight: DS.Layout.rowHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(formatted)
    }

    @ViewBuilder
    private var slider: some View {
        if step > 0 {
            Slider(value: $value, in: range, step: step)
        } else {
            Slider(value: $value, in: range)
        }
    }

    var formatted: String { Self.format(value, step: step, unit: unit) }

    static func format(_ v: Double, step: Double, unit: String) -> String {
        switch unit {
        case "%":
            return "\(Int((v * 100).rounded())) %"
        case "×":
            return String(format: "%.1f×", v)
        case "s":
            return String(format: "%.2f s", v)
        default:
            let number = step < 1 ? String(format: "%.1f", v) : "\(Int(v.rounded()))"
            return unit.isEmpty ? number : "\(number) \(unit)"
        }
    }
}

// MARK: - Colors

struct ColorRow: View {
    let title: String
    @Binding var color: RGBAColor

    init(_ title: String, color: Binding<RGBAColor>) {
        self.title = title
        self._color = color
    }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            RowLabel(title: title)
            Spacer(minLength: 0)
            ValueReadout(text: color.hexString, width: 92)
                .textSelection(.enabled)
                .contextMenu {
                    Button("Kopírovať hex kód") { copyHex(color.hexString) }
                }
            ColorPicker("", selection: swiftUIColor, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 44)
        }
        .frame(minHeight: DS.Layout.rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var swiftUIColor: Binding<Color> {
        Binding(get: { Color(color) },
                set: { newValue in
                    let converted = RGBAColor(newValue)
                    if converted != color { color = converted }
                })
    }
}

struct OptionalColorRow: View {
    let title: String
    @Binding var color: RGBAColor?
    let defaultColor: RGBAColor
    /// Remembers the last color while switched off, so toggling back restores it.
    @State private var lastColor: RGBAColor?

    init(_ title: String, color: Binding<RGBAColor?>, defaultColor: RGBAColor) {
        self.title = title
        self._color = color
        self.defaultColor = defaultColor
    }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            RowLabel(title: title)
            Toggle("", isOn: isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            Spacer(minLength: 0)
            ValueReadout(text: color?.hexString ?? "Vypnuté", width: 92)
            ColorPicker("", selection: pickerColor, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 44)
                .disabled(color == nil)
                .opacity(color == nil ? 0.4 : 1)
        }
        .frame(minHeight: DS.Layout.rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var isEnabled: Binding<Bool> {
        Binding(get: { color != nil },
                set: { on in
                    if on {
                        color = lastColor ?? defaultColor
                    } else {
                        lastColor = color
                        color = nil
                    }
                })
    }

    private var pickerColor: Binding<Color> {
        Binding(get: { Color(color ?? lastColor ?? defaultColor) },
                set: { newValue in
                    let converted = RGBAColor(newValue)
                    if converted != color { color = converted }
                })
    }
}

private func copyHex(_ hex: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(hex, forType: .string)
}

// MARK: - Toggle

struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.rowTitle)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DS.Spacing.m)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .frame(minHeight: DS.Layout.rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Zapnuté" : "Vypnuté")
    }
}

// MARK: - Picker

enum PickerRowStyle {
    case menu, segmented
}

struct PickerRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let style: PickerRowStyle
    let label: (T) -> String

    init(_ title: String, selection: Binding<T>, options: [T], style: PickerRowStyle = .menu,
         label: @escaping (T) -> String) {
        self.title = title
        self._selection = selection
        self.options = options
        self.style = style
        self.label = label
    }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            RowLabel(title: title)
            styledPicker
            if style == .menu { Spacer(minLength: 0) }
        }
        .frame(minHeight: DS.Layout.rowHeight)
    }

    private var picker: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
        .labelsHidden()
    }

    @ViewBuilder
    private var styledPicker: some View {
        switch style {
        case .menu:
            picker
                .pickerStyle(.menu)
                .fixedSize()
        case .segmented:
            picker
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
        }
    }
}
