import SwiftUI
import AppKit
import DoxCore

/// Click-to-record global shortcut field.
/// Esc cancels, ⌫ (without modifiers) clears, a shortcut needs at least one modifier.
/// Conflicts with other Dox shortcuts are shown below the field.
@MainActor
struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    /// The dock this recorder belongs to (excluded from conflict detection).
    var excludingDock: UUID?
    /// Name this shortcut has in `AppConfig.shortcutConflicts` (excluded from conflict detection).
    var ownName: String?

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var hovering = false
    @State private var hint: String?

    init(shortcut: Binding<KeyShortcut?>, excludingDock: UUID? = nil, ownName: String? = nil) {
        self._shortcut = shortcut
        self.excludingDock = excludingDock
        self.ownName = ownName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: toggleRecording) {
                    field
                }
                .buttonStyle(.plain)
                .help(isRecording ? "Stlač skratku · Esc zruší · ⌫ vymaže" : "Klikni a stlač novú skratku")

                if shortcut != nil && !isRecording {
                    Button {
                        shortcut = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Vymazať skratku")
                    .transition(.opacity)
                }
            }
            if let hint {
                SettingsCaption(hint, symbol: "info.circle")
                    .transition(.opacity)
            } else if !conflicts.isEmpty {
                Label("Koliduje s: \(conflicts.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Font.caption)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }
        }
        .animation(DS.Motion.snappy, value: isRecording)
        .animation(DS.Motion.snappy, value: shortcut)
        .animation(DS.Motion.snappy, value: hint)
        .onDisappear(perform: stopRecording)
    }

    private var field: some View {
        HStack(spacing: 6) {
            Image(systemName: isRecording ? "record.circle" : "command")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isRecording ? AnyShapeStyle(Color.red) : AnyShapeStyle(DS.Color.accent))
                .symbolEffect(.pulse, isActive: isRecording)
            Text(label)
                .font(shortcut != nil && !isRecording ? DS.Font.mono : DS.Font.caption)
                .foregroundStyle(shortcut == nil || isRecording ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 150, minHeight: 26, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                .fill(DS.Color.readoutBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                .strokeBorder(isRecording ? DS.Color.accent : (hovering ? Color.primary.opacity(0.25) : DS.Color.cardBorder),
                              lineWidth: isRecording ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var label: String {
        if isRecording { return "Stlač skratku…" }
        return shortcut?.displayString ?? "Nastaviť skratku"
    }

    private var conflicts: [String] {
        guard let shortcut else { return [] }
        return DoxStore.shared.config
            .shortcutConflicts(for: shortcut, excludingDock: excludingDock)
            .filter { $0 != ownName }
    }

    // MARK: Recording

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        stopRecording()
        hint = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let consumed = MainActor.assumeIsolated { handle(event) }
            return consumed ? nil : event
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    /// - Returns: true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        switch event.keyCode {
        case 53: // Esc
            stopRecording()
            return true
        case 51, 117 where mods.isEmpty: // ⌫ / ⌦
            shortcut = nil
            stopRecording()
            return true
        default:
            break
        }
        guard let recorded = KeyShortcut(event: event) else {
            NSSound.beep()
            return true
        }
        guard recorded.isValidGlobalShortcut else {
            hint = "Pridaj aspoň jeden modifikátor: ⌘ ⌥ ⌃ alebo ⇧."
            NSSound.beep()
            return true
        }
        shortcut = recorded
        hint = nil
        stopRecording()
        return true
    }
}

// MARK: - Shortcuts page

@MainActor
struct ShortcutsPage: View {
    private var store: DoxStore { DoxStore.shared }

    var body: some View {
        SettingsScrollPage {
            SettingsPageHeader(title: "Skratky",
                               subtitle: "Globálne klávesové skratky fungujú v ktorejkoľvek aplikácii.",
                               symbol: "command")

            SettingsSection("Aplikácia", symbol: "app.connected.to.app.below.fill") {
                FieldRow("Zobraziť/skryť všetky") {
                    ShortcutRecorder(shortcut: store.binding(\.toggleAllShortcut),
                                     ownName: "Zobraziť/skryť všetky docky")
                }
                FieldRow("Otvoriť nastavenia") {
                    ShortcutRecorder(shortcut: store.binding(\.settingsShortcut), ownName: "Nastavenia")
                }
            }

            SettingsSection("Docky", symbol: "dock.rectangle") {
                if store.config.docks.isEmpty {
                    SettingsCaption("Zatiaľ nemáš žiadny dock.")
                }
                ForEach(store.config.docks) { dock in
                    HStack(spacing: DS.Spacing.m) {
                        HStack(spacing: DS.Spacing.s) {
                            Image(systemName: dock.edge.symbol)
                                .foregroundStyle(Color(dock.appearance.accent))
                                .frame(width: 18)
                            Text(dock.name)
                                .font(DS.Font.rowTitle)
                                .lineLimit(1)
                        }
                        .frame(width: DS.Layout.labelWidth, alignment: .leading)
                        ShortcutRecorder(shortcut: store.binding(dock: dock.id, \.shortcut), excludingDock: dock.id)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: DS.Layout.rowHeight)
                    if dock.id != store.config.docks.last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }

            SettingsCaption("Klikni na pole a stlač kombináciu. Esc nahrávanie zruší, ⌫ skratku vymaže.",
                            symbol: "keyboard")
        }
    }
}
