import AppKit
import Carbon
import DoxCore

/// Translation between macOS virtual key codes (kVK_*) and short human readable labels.
enum KeyCodes {
    /// Keys whose label is a fixed symbol/name regardless of keyboard layout.
    private static let specialKeys: [Int: String] = [
        kVK_Space: "␣",
        kVK_Return: "↩",
        kVK_ANSI_KeypadEnter: "⌤",
        kVK_Tab: "⇥",
        kVK_Escape: "⎋",
        kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_UpArrow: "↑",
        kVK_DownArrow: "↓",
        kVK_Home: "↖",
        kVK_End: "↘",
        kVK_PageUp: "⇞",
        kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    /// US-ANSI fallback used when the event carries no usable characters.
    private static let ansiKeys: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
        kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
        kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
        kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".",
        kVK_ANSI_Slash: "/", kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`",
    ]

    /// Key codes of pure modifier keys; these can never be the "key" of a shortcut.
    static let modifierKeyCodes: Set<Int> = [
        kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift, kVK_Option, kVK_RightOption,
        kVK_Control, kVK_RightControl, kVK_CapsLock, kVK_Function,
    ]

    /// Short label for a key, e.g. "D", "F5", "←", "␣".
    /// - Parameter characters: `NSEvent.charactersIgnoringModifiers`, used so letters follow the
    ///   user's keyboard layout (QWERTZ etc.).
    static func label(for keyCode: UInt16, characters: String?) -> String {
        let code = Int(keyCode)
        if let special = specialKeys[code] { return special }
        if let chars = characters?.trimmingCharacters(in: .whitespacesAndNewlines),
           chars.count == 1,
           let scalar = chars.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(scalar),
           scalar.value < 0xF700 || scalar.value > 0xF8FF { // skip AppKit private-use function keys
            return chars.uppercased()
        }
        if let ansi = ansiKeys[code] { return ansi }
        return "#\(code)"
    }
}

extension KeyShortcut {
    /// Builds a global shortcut from a key-down event. Requires at least one of ⌘ ⌥ ⌃
    /// (⇧ alone would hijack normal typing). Returns nil for modifier-only key presses.
    @MainActor
    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        guard !KeyCodes.modifierKeyCodes.contains(Int(event.keyCode)) else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: KeyShortcut.Modifiers = []
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.control) { mods.insert(.control) }
        if flags.contains(.shift) { mods.insert(.shift) }
        guard mods.contains(.command) || mods.contains(.option) || mods.contains(.control) else { return nil }
        let label = KeyCodes.label(for: event.keyCode, characters: event.charactersIgnoringModifiers)
        self.init(keyCode: UInt32(event.keyCode), modifiers: mods, keyLabel: label)
    }

    /// Modifier mask in the Carbon format expected by `RegisterEventHotKey`.
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
