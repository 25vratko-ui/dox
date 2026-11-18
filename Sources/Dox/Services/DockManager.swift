import AppKit
import Observation
import DoxCore

/// Creates and drives one `DockPanelController` per dock (per screen for `DisplayTarget.all`).
@MainActor
@Observable
final class DockManager {
    static let shared = DockManager()

    /// `.manual` docks currently shown via shortcut / menu.
    private(set) var revealedManualIDs: Set<UUID> = []

    private struct PanelKey: Hashable {
        let dockID: UUID
        /// Only set for `DisplayTarget.all` (one panel per display).
        let displayID: CGDirectDisplayID?
    }

    @ObservationIgnored private var controllers: [PanelKey: DockPanelController] = [:]
    @ObservationIgnored private var started = false
    @ObservationIgnored private var lockedDockIDs: Set<UUID> = []
    @ObservationIgnored private var fullScreenDisplayIDs: Set<CGDirectDisplayID> = []
    @ObservationIgnored private var lastMouseDisplayID: CGDirectDisplayID?
    @ObservationIgnored private var eventMonitors: [Any] = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var fullScreenRecheck: Task<Void, Never>?

    private init() {}

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true

        DoxStore.shared.onChange.append { [weak self] _ in
            self?.sync()
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            onMainActor {
                self?.sync()
                self?.scheduleFullScreenCheck()
            }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                onMainActor { self?.scheduleFullScreenCheck() }
            })
        }

        // Global: pointer over other apps (incl. while our panels ignore mouse events).
        // Local: pointer over our own windows.
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            onMainActor { self?.mouseMoved() }
        }) {
            eventMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            onMainActor { self?.mouseMoved() }
            return event
        }) {
            eventMonitors.append(local)
        }
        // Safety net for moments when no mouse-moved events are generated (e.g. pointer over a
        // window that does not accept them). Cheap: a few rect checks.
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            onMainActor { self?.mouseMoved() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        lastMouseDisplayID = screenWithMouse()?.displayID
        sync()
        scheduleFullScreenCheck()
    }

    // MARK: Public API

    /// Shows a dock: unhides it, reveals a `.manual` dock, slides an `.auto` dock in.
    func reveal(dockID: UUID) {
        let store = DoxStore.shared
        guard let dock = store.dock(dockID) else { return }
        if store.hiddenDockIDs.contains(dockID) { store.toggleVisibility(of: dockID) }
        switch dock.behavior.autoHide {
        case .manual:
            revealedManualIDs.insert(dockID)
            applyVisibility()
        case .auto:
            for c in panels(for: dockID) { c.expand(holdOpen: true) }
        case .never:
            break
        }
    }

    /// Hides a dock the way its mode allows: `.auto` slides away, `.manual` disappears,
    /// `.never` stays (use `DoxStore.toggleVisibility` to force-hide those).
    func hide(dockID: UUID) {
        guard let dock = DoxStore.shared.dock(dockID) else { return }
        switch dock.behavior.autoHide {
        case .manual:
            revealedManualIDs.remove(dockID)
            applyVisibility()
        case .auto:
            for c in panels(for: dockID) { c.collapse() }
        case .never:
            break
        }
    }

    /// Per-dock keyboard shortcut action.
    func toggle(dockID: UUID) {
        let store = DoxStore.shared
        guard let dock = store.dock(dockID) else { return }
        if store.hiddenDockIDs.contains(dockID) {
            reveal(dockID: dockID)
            return
        }
        switch dock.behavior.autoHide {
        case .manual:
            if revealedManualIDs.contains(dockID) { hide(dockID: dockID) } else { reveal(dockID: dockID) }
        case .auto:
            if panels(for: dockID).contains(where: { $0.isCollapsed }) {
                reveal(dockID: dockID)
            } else {
                hide(dockID: dockID)
            }
        case .never:
            store.toggleVisibility(of: dockID)
        }
    }

    /// Whether the dock is currently "on" (menu checkmark). Observable.
    func isDockShown(_ dockID: UUID) -> Bool {
        let store = DoxStore.shared
        if store.hiddenDockIDs.contains(dockID) { return false }
        if store.dock(dockID)?.behavior.autoHide == .manual { return revealedManualIDs.contains(dockID) }
        return true
    }

    /// Menu toggle: shows / hides a dock regardless of its auto-hide mode.
    func setDockShown(_ dockID: UUID, _ shown: Bool) {
        let store = DoxStore.shared
        guard let dock = store.dock(dockID) else { return }
        let hidden = store.hiddenDockIDs.contains(dockID)
        if dock.behavior.autoHide == .manual {
            if shown { revealedManualIDs.insert(dockID) } else { revealedManualIDs.remove(dockID) }
            if shown && hidden { store.toggleVisibility(of: dockID) } else { applyVisibility() }
        } else if shown == hidden {
            store.toggleVisibility(of: dockID)
        }
    }

    /// The dock UI calls this while a popover / context menu / editor of `dockID` is open, so
    /// auto-hide does not slide the dock away underneath it.
    func setInteractionLock(dockID: UUID, locked: Bool) {
        if locked {
            lockedDockIDs.insert(dockID)
        } else {
            lockedDockIDs.remove(dockID)
            let p = NSEvent.mouseLocation
            for c in panels(for: dockID) { c.handleMouse(at: p) }
        }
    }

    func isInteractionLocked(_ dockID: UUID) -> Bool {
        lockedDockIDs.contains(dockID)
    }

    // MARK: Sync

    /// Creates / updates / removes panels to match the config and connected screens.
    private func sync() {
        guard started else { return }
        let config = DoxStore.shared.config
        var desired: [PanelKey: (DockConfig, NSScreen)] = [:]
        for dock in config.docks where dock.isEnabled {
            for (displayID, screen) in screens(for: dock.behavior.display) {
                desired[PanelKey(dockID: dock.id, displayID: displayID)] = (dock, screen)
            }
        }

        for (key, controller) in controllers where desired[key] == nil {
            controller.close()
            controllers[key] = nil
        }
        for (key, value) in desired {
            if let controller = controllers[key] {
                controller.update(dock: value.0, screen: value.1)
            } else {
                controllers[key] = DockPanelController(dock: value.0, screen: value.1)
            }
        }
        let liveIDs = Set(config.docks.map(\.id))
        // Only write observable state when it actually changes (avoids needless view updates).
        let liveManual = revealedManualIDs.intersection(liveIDs)
        if liveManual != revealedManualIDs { revealedManualIDs = liveManual }
        lockedDockIDs.formIntersection(liveIDs)
        applyVisibility()
    }

    private func screens(for target: DisplayTarget) -> [(CGDirectDisplayID?, NSScreen)] {
        let all = NSScreen.screens
        guard let primary = all.first else { return [] }
        switch target {
        case .main:
            return [(nil, primary)]
        case .withMouse:
            return [(nil, screenWithMouse() ?? primary)]
        case .named(let name):
            return [(nil, all.first { $0.localizedName == name } ?? primary)]
        case .all:
            return all.map { ($0.displayID, $0) }
        }
    }

    private func screenWithMouse() -> NSScreen? {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) }
    }

    private func panels(for dockID: UUID) -> [DockPanelController] {
        controllers.values.filter { $0.dockID == dockID }
    }

    private func applyVisibility() {
        for controller in controllers.values {
            controller.setShown(shouldShow(controller))
        }
    }

    private func shouldShow(_ controller: DockPanelController) -> Bool {
        let dock = controller.dock
        if DoxStore.shared.hiddenDockIDs.contains(dock.id) { return false }
        if dock.behavior.autoHide == .manual && !revealedManualIDs.contains(dock.id) { return false }
        if dock.behavior.hideInFullScreen && fullScreenDisplayIDs.contains(controller.displayID) { return false }
        return true
    }

    // MARK: Pointer

    private func mouseMoved() {
        let p = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) }) {
            let id = screen.displayID
            if id != lastMouseDisplayID {
                lastMouseDisplayID = id
                let followsMouse = DoxStore.shared.config.docks.contains {
                    $0.isEnabled && $0.behavior.display == .withMouse
                }
                if followsMouse { sync() }
            }
        }
        for controller in controllers.values { controller.handleMouse(at: p) }
    }

    // MARK: Full screen

    private func scheduleFullScreenCheck() {
        refreshFullScreenState()
        fullScreenRecheck?.cancel()
        // Space-switch animations finish after the notification; check again shortly after.
        fullScreenRecheck = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled else { return }
            self.refreshFullScreenState()
        }
    }

    /// Marks displays on which an on-screen, normal-level window of another app covers the whole
    /// screen frame (native full screen, or a borderless full-screen game/video).
    private func refreshFullScreenState() {
        var covered = Set<CGDirectDisplayID>()
        let anyDockCares = DoxStore.shared.config.docks.contains { $0.isEnabled && $0.behavior.hideInFullScreen }
        if anyDockCares,
           let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] {
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let screens = NSScreen.screens
            let primaryHeight = screens.first?.frame.height ?? 0
            // Screen frames converted to CoreGraphics (top-left origin) coordinates.
            let cgFrames: [(CGDirectDisplayID, CGRect)] = screens.map { screen in
                let f = screen.frame
                return (screen.displayID, CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height))
            }
            for info in list {
                guard let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue, layer == 0,
                      let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pid != ownPID,
                      let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                      let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
                for (id, frame) in cgFrames
                where abs(bounds.minX - frame.minX) < 1 && abs(bounds.minY - frame.minY) < 1
                    && bounds.width >= frame.width - 1 && bounds.height >= frame.height - 1 {
                    covered.insert(id)
                }
            }
        }
        if covered != fullScreenDisplayIDs {
            fullScreenDisplayIDs = covered
            applyVisibility()
        }
    }
}
