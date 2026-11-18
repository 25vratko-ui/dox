import SwiftUI
import AppKit
import DoxCore

/// "Vzhľad" tab: theme gallery + every field of `DockAppearance`.
@MainActor
struct DockAppearanceTab: View {
    let dockID: UUID

    @State private var selectedThemeID: UUID?
    @State private var keepSizing = true
    @State private var showSaveTheme = false
    @State private var newThemeName = ""

    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        if let dock = store.dock(dockID) {
            let a = dock.appearance
            SettingsScrollPage {
                themesSection(a)

                SettingsSection("Pozadie", symbol: "square.fill.on.square.fill") {
                    PickerRow("Režim", selection: b(\.mode), options: AppearanceMode.allCases,
                              style: .segmented) { $0.displayName }
                    PickerRow("Materiál", selection: b(\.material), options: DockMaterial.allCases) { $0.displayName }
                    ColorRow("Farba tónovania", color: b(\.tint))
                    SliderRow("Sila tónovania", value: b(\.tintOpacity), in: 0...1, unit: "%")
                    OptionalColorRow("Koniec prechodu", color: b(\.gradientEnd), defaultColor: a.tint)
                    SliderRow("Priehľadnosť pozadia", value: b(\.backgroundOpacity), in: 0...1, unit: "%")
                    ColorRow("Akcentová farba", color: b(\.accent))
                }

                SettingsSection("Ikony", symbol: "app.fill") {
                    SliderRow("Veľkosť ikon", value: b(\.iconSize), in: DockAppearance.iconSizeRange)
                    PickerRow("Tvar ikon", selection: b(\.iconShape), options: IconShape.allCases,
                              style: .segmented) { $0.displayName }
                    ToggleRow("Tieň ikon", isOn: b(\.iconShadow))
                    SliderRow("Rozostup ikon", value: b(\.iconSpacing), in: DockAppearance.spacingRange)
                    SliderRow("Vnútorný okraj", value: b(\.padding), in: DockAppearance.paddingRange)
                }

                SettingsSection("Tvar a tieň", symbol: "square.on.square.dashed") {
                    SliderRow("Zaoblenie rohov", value: b(\.cornerRadius), in: DockAppearance.cornerRadiusRange)
                    SliderRow("Hrúbka okraja", value: b(\.borderWidth), in: DockAppearance.borderWidthRange, step: 0.5)
                    ColorRow("Farba okraja", color: b(\.borderColor))
                        .disabled(a.borderWidth == 0)
                    SliderRow("Rozptyl tieňa", value: b(\.shadowRadius), in: DockAppearance.shadowRadiusRange)
                    SliderRow("Sýtosť tieňa", value: b(\.shadowOpacity), in: 0...1, unit: "%")
                }

                SettingsSection("Interakcia", symbol: "cursorarrow.motionlines") {
                    PickerRow("Efekt pod kurzorom", selection: b(\.hoverEffect), options: HoverEffect.allCases,
                              style: .segmented) { $0.displayName }
                    Group {
                        SliderRow("Zväčšenie", value: b(\.magnification), in: DockAppearance.magnificationRange,
                                  step: 0.05, unit: "×")
                        SliderRow("Dosah zväčšenia", value: b(\.magnificationSpread),
                                  in: DockAppearance.magnificationSpreadRange, step: 0.5, unit: "ikon")
                    }
                    .disabled(a.hoverEffect != .magnify)
                    .opacity(a.hoverEffect == .magnify ? 1 : 0.5)
                    SliderRow("Rýchlosť animácií", value: b(\.animationSpeed), in: DockAppearance.animationSpeedRange,
                              step: 0.1, unit: "×")
                    SettingsCaption(a.animationSpeed < 0.01
                                    ? "Animácie sú vypnuté."
                                    : "Násobok dĺžky animácií – menej je rýchlejšie, 0 animácie vypne.")
                }

                SettingsSection("Popisky a kategórie", symbol: "tag.fill") {
                    PickerRow("Popisky", selection: b(\.labelMode), options: LabelMode.allCases,
                              style: .segmented) { $0.displayName }
                    SliderRow("Veľkosť písma popisku", value: b(\.labelFontSize), in: DockAppearance.labelFontSizeRange)
                        .disabled(a.labelMode == .never)
                    PickerRow("Hlavička kategórie", selection: b(\.categoryHeaderStyle),
                              options: CategoryHeaderStyle.allCases) { $0.displayName }
                    SliderRow("Medzera medzi kategóriami", value: b(\.categorySpacing),
                              in: DockAppearance.categorySpacingRange)
                    PickerRow("Indikátor spustenej appky", selection: b(\.runningIndicator),
                              options: RunningIndicator.allCases, style: .segmented) { $0.displayName }
                }

                HStack {
                    Spacer()
                    Button {
                        store.updateDock(dockID) { $0.appearance = DockAppearance() }
                    } label: {
                        Label("Obnoviť predvolený vzhľad", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
            .alert("Uložiť ako tému", isPresented: $showSaveTheme) {
                TextField("Názov témy", text: $newThemeName)
                Button("Uložiť") {
                    let name = newThemeName.trimmingCharacters(in: .whitespaces)
                    store.saveCurrentAppearanceAsTheme(dock: dockID, name: name.isEmpty ? "Moja téma" : name)
                    selectedThemeID = store.config.customThemes.last?.id
                }
                Button("Zrušiť", role: .cancel) {}
            } message: {
                Text("Aktuálny vzhľad docku sa uloží medzi tvoje témy.")
            }
        }
    }

    // MARK: Themes

    private func themesSection(_ a: DockAppearance) -> some View {
        let themes = store.config.allThemes
        let activeID = themes.first { $0.appearance == a }?.id
        let selection = selectedThemeID ?? activeID
        return SettingsSection("Témy", symbol: "paintpalette.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.m) {
                    ForEach(themes) { theme in
                        ThemeCard(theme: theme, isSelected: theme.id == selection)
                            .onTapGesture(count: 2) { apply(theme) }
                            .onTapGesture { withAnimation(DS.Motion.snappy) { selectedThemeID = theme.id } }
                            .overlay(alignment: .topLeading) {
                                if theme.id == activeID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.white, DS.Color.accent)
                                        .padding(6)
                                        .help("Aktuálne použitá téma")
                                }
                            }
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
                .padding(.horizontal, 2)
            }
            HStack(spacing: DS.Spacing.s) {
                Toggle("Zachovať veľkosti a popisky", isOn: $keepSizing)
                    .toggleStyle(.checkbox)
                    .font(DS.Font.caption)
                Spacer()
                Button {
                    newThemeName = ""
                    showSaveTheme = true
                } label: {
                    Label("Uložiť ako tému…", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(SoftButtonStyle())
                Button {
                    if let id = selection, let theme = themes.first(where: { $0.id == id }) { apply(theme) }
                } label: {
                    Label("Použiť", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selection == nil || selection == activeID)
            }
        }
    }

    private func apply(_ theme: ThemePreset) {
        let keep = keepSizing
        withAnimation(.easeInOut(duration: 0.25)) {
            store.updateDock(dockID) { $0.appearance = theme.apply(to: $0.appearance, keepSizing: keep) }
        }
        selectedThemeID = theme.id
    }

    // MARK: Binding

    private func b<T: Equatable>(_ keyPath: WritableKeyPath<DockAppearance, T>) -> Binding<T> {
        store.binding(dock: dockID, (\DockConfig.appearance).appending(path: keyPath))
    }
}
