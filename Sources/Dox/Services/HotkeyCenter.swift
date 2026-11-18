import AppKit
import Carbon
import DoxCore

/// System-wide keyboard shortcuts via Carbon `RegisterEventHotKey`
/// (works without Accessibility permission).
@MainActor
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    private struct Entry {
        let ref: EventHotKeyRef
        let id: String
        let action: () -> Void
    }

    /// 'Dox!' – signature identifying our hot keys.
    private let signature: OSType = 0x446F_7821
    private var entries: [UInt32: Entry] = [:]
    private var nextNumber: UInt32 = 1
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// Registers `shortcut`. `id` is a caller-chosen name used for logging / diagnostics.
    /// Invalid shortcuts (no modifier) are ignored.
    func register(_ shortcut: KeyShortcut, id: String, action: @escaping () -> Void) {
        guard shortcut.isValidGlobalShortcut else { return }
        installHandlerIfNeeded()
        let number = nextNumber
        nextNumber &+= 1
        let hotKeyID = EventHotKeyID(signature: signature, id: number)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            NSLog("Dox: could not register hot key \(shortcut.displayString) for \(id) (status \(status))")
            return
        }
        entries[number] = Entry(ref: ref, id: id, action: action)
    }

    func unregisterAll() {
        for entry in entries.values { UnregisterEventHotKey(entry.ref) }
        entries.removeAll()
    }

    fileprivate func fire(_ number: UInt32) {
        entries[number]?.action()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(event,
                                        EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID),
                                        nil,
                                        MemoryLayout<EventHotKeyID>.size,
                                        nil,
                                        &hotKeyID)
            guard err == noErr else { return err }
            let number = hotKeyID.id
            Task { @MainActor in HotkeyCenter.shared.fire(number) }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        if status != noErr { NSLog("Dox: InstallEventHandler failed (\(status))") }
    }
}
