import SwiftUI
import AppKit
import DoxCore

// MARK: - Rozloženie

@MainActor
struct DockLayoutTab: View {
    let dockID: UUID

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        if let dock = store.dock(dockID) {
            SettingsScrollPage {
                SettingsSection("Umiestnenie", symbol: "rectangle.portrait.and.arrow.right") {
                    HStack(alignment: .center, spacing: DS.Spacing.xl) {
                        EdgePicker(selection: store.binding(dock: dockID, \.edge),
                                   accent: Color(dock.appearance.accent))
                        VStack(alignment: .leading, spacing: DS.Spacing.s) {
                            Text("Hrana obrazovky")
                                .font(DS.Font.rowTitle)
                            Text(dock.edge.displayName)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .contentTransition(.opacity)
                            SettingsCaption("Klikni na hranu miniatúry obrazovky. Zväčšené ikony a popisky rastú smerom od hrany.")
                        }
                        Spacer(minLength: 0)
                    }
                    Divider().padding(.vertical, DS.Spacing.xs)
                    PickerRow("Zarovnanie", selection: store.binding(dock: dockID, \.behavior.alignment),
                              options: EdgeAlignment.allCases, style: .segmented) { alignmentName($0, edge: dock.edge) }
                    SliderRow("Posun pozdĺž hrany", value: store.binding(dock: dockID, \.behavior.alignmentOffset),
                              in: -0.5...0.5, unit: "%")
                    SliderRow("Odstup od hrany", value: store.binding(dock: dockID, \.behavior.edgeInset), in: 0...80)
                }

                SettingsSection("Usporiadanie ikon", symbol: "square.grid.3x2.fill") {
                    PickerRow("Štýl", selection: store.binding(dock: dockID, \.layout),
                              options: DockLayoutStyle.allCases, style: .segmented) { $0.displayName }
                    FieldRow(dock.edge.isVertical ? "Počet stĺpcov" : "Počet radov") {
                        Stepper(value: store.binding(dock: dockID, \.gridLines), in: 1...6) {
                            ValueReadout(text: "\(dock.gridLines)", width: 36)
                        }
                    }
                    .disabled(dock.layout != .grid)
                    .opacity(dock.layout == .grid ? 1 : 0.5)
                    SettingsCaption(layoutCaption(dock.layout))
                }

                SettingsSection("Displej", symbol: "display") {
                    PickerRow("Zobraziť na", selection: store.binding(dock: dockID, \.behavior.display),
                              options: displayOptions(current: dock.behavior.display)) { $0.displayName }
                    if case .named(let name) = dock.behavior.display,
                       !NSScreen.screens.contains(where: { $0.localizedName == name }) {
                        SettingsCaption("Displej „\(name)“ nie je pripojený – dock sa zobrazí na hlavnom displeji.",
                                        symbol: "exclamationmark.triangle.fill")
                    }
                }
            }
        }
    }

    private func displayOptions(current: DisplayTarget) -> [DisplayTarget] {
        var options: [DisplayTarget] = [.main, .withMouse, .all]
        for screen in NSScreen.screens {
            let target = DisplayTarget.named(screen.localizedName)
            if !options.contains(target) { options.append(target) }
        }
        if !options.contains(current) { options.append(current) }
        return options
    }

    private func alignmentName(_ alignment: EdgeAlignment, edge: DockEdge) -> String {
        switch alignment {
        case .leading: edge.isVertical ? "Hore" : "Vľavo"
        case .center: "Stred"
        case .trailing: edge.isVertical ? "Dole" : "Vpravo"
        }
    }

    private func layoutCaption(_ layout: DockLayoutStyle) -> String {
        switch layout {
        case .line: "Všetky kategórie v jednom rade, oddelené hlavičkami."
        case .grid: "Ikony sa zalomia do viacerých radov; dlaždice nesú farbu svojej kategórie."
        case .shelves: "Každá kategória dostane vlastnú policu."
        }
    }
}

/// Miniature screen with four clickable edges.
@MainActor
struct EdgePicker: View {
    @Binding var selection: DockEdge
    let accent: Color

    @State private var hovered: DockEdge?

    var body: some View {
        ZStack {
            PreviewWallpaper()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            // Menu bar hint.
            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 6)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            ForEach(DockEdge.allCases) { edge in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = edge }
                } label: {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill(for: edge))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.white.opacity(selection == edge ? 0.6 : 0.25), lineWidth: 0.75))
                        .frame(width: edge.isVertical ? 12 : 92, height: edge.isVertical ? 64 : 12)
                        .shadow(color: selection == edge ? accent.opacity(0.6) : .clear, radius: 6)
                        .contentShape(Rectangle().inset(by: -6))
                }
                .buttonStyle(.plain)
                .onHover { h in hovered = h ? edge : (hovered == edge ? nil : hovered) }
                .help(edge.displayName)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge.bodyAlignment)
                .padding(edge == .top ? EdgeInsets(top: 12, leading: 8, bottom: 8, trailing: 8)
                                      : EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
        }
        .frame(width: 200, height: 128)
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(DS.Color.cardBorder, lineWidth: 1))
        .animation(DS.Motion.snappy, value: hovered)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hrana obrazovky")
    }

    private func fill(for edge: DockEdge) -> Color {
        if selection == edge { return accent }
        return Color.white.opacity(hovered == edge ? 0.55 : 0.22)
    }
}

// MARK: - Správanie

@MainActor
struct DockBehaviorTab: View {
    let dockID: UUID

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        if let dock = store.dock(dockID) {
            let behavior = dock.behavior
            SettingsScrollPage {
                SettingsSection("Skrývanie", symbol: "eye.slash.fill") {
                    PickerRow("Viditeľnosť", selection: b(\.autoHide), options: AutoHideMode.allCases,
                              style: .segmented) { $0.displayName }
                    Group {
                        SliderRow("Oneskorenie skrytia", value: b(\.hideDelay), in: 0...3, step: 0.05, unit: "s")
                        SliderRow("Oneskorenie zobrazenia", value: b(\.revealDelay), in: 0...2, step: 0.05, unit: "s")
                    }
                    .disabled(behavior.autoHide != .auto)
                    .opacity(behavior.autoHide == .auto ? 1 : 0.5)
                    ToggleRow("Skryť po otvorení položky",
                              subtitle: "Dock sa schová hneď, ako z neho niečo spustíš.",
                              isOn: b(\.hideAfterLaunch))
                    SettingsCaption(autoHideCaption(behavior.autoHide))
                }

                SettingsSection("Okno", symbol: "macwindow.on.rectangle") {
                    ToggleRow("Vždy navrchu", subtitle: "Dock zostane nad oknami ostatných aplikácií.",
                              isOn: b(\.alwaysOnTop))
                    ToggleRow("Na všetkých plochách", subtitle: "Zobrazí sa v každom Spaces.",
                              isOn: b(\.showOnAllSpaces))
                    ToggleRow("Skryť pri celoobrazovkovej aplikácii", isOn: b(\.hideInFullScreen))
                }

                SettingsSection("Kliknutie", symbol: "cursorarrow.click.2") {
                    PickerRow("Kliknutie na položku", selection: b(\.clickAction), options: ClickAction.allCases,
                              style: .segmented) { $0.displayName }
                    SettingsCaption("⌥-klik vždy urobí opačnú akciu. Priečinky po kliknutí zobrazia svoj obsah.",
                                    symbol: "option")
                    ToggleRow("Zobrazovať spustené aplikácie",
                              subtitle: "Pod ikonou bežiacej aplikácie sa zobrazí indikátor.",
                              isOn: b(\.showRunningApps))
                }
            }
        }
    }

    private func autoHideCaption(_ mode: AutoHideMode) -> String {
        switch mode {
        case .never: "Dock je stále na obrazovke."
        case .auto: "Dock sa vysunie, keď podržíš kurzor pri hrane obrazovky."
        case .manual: "Dock sa zobrazí iba klávesovou skratkou alebo z ponuky v lište."
        }
    }

    private func b<T: Equatable>(_ keyPath: WritableKeyPath<DockBehavior, T>) -> Binding<T> {
        store.binding(dock: dockID, (\DockConfig.behavior).appending(path: keyPath))
    }
}

// MARK: - Skratka

@MainActor
struct DockShortcutTab: View {
    let dockID: UUID

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        if let dock = store.dock(dockID) {
            SettingsScrollPage {
                SettingsSection("Klávesová skratka docku", symbol: "keyboard.fill") {
                    FieldRow("Zobraziť / skryť") {
                        ShortcutRecorder(shortcut: store.binding(dock: dockID, \.shortcut), excludingDock: dockID)
                    }
                    SettingsCaption(dock.behavior.autoHide == .manual
                                    ? "Dock je nastavený „Iba skratkou“ – táto skratka ho vyvolá."
                                    : "Skratka funguje globálne, aj keď je aktívna iná aplikácia. Musí obsahovať ⌘, ⌥ alebo ⌃ (⇧ je voliteľný).")
                }
            }
        }
    }
}
