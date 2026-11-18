import AppKit

/// Runs `body` on the main actor from AppKit callbacks that are documented to arrive on the main
/// thread (notification blocks with `queue: .main`, NSEvent monitors, main run-loop timers) but are
/// typed as non-isolated / `@Sendable` closures.
func onMainActor(_ body: @MainActor () -> Void) {
    MainActor.assumeIsolated(body)
}

extension NSScreen {
    /// Stable CoreGraphics id of the display backing this screen.
    @MainActor
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}
