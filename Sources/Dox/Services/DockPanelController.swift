import AppKit
import SwiftUI
import QuartzCore
import DoxCore

/// Owns one `DockPanel` for one dock on one screen: placement, show/hide, auto-hide and
/// click-through of the transparent headroom.
///
/// Click-through: the panel is larger than the visible dock (magnification headroom + shadow
/// margin). Instead of a `hitTest` override (which would swallow clicks rather than pass them
/// to the window below), `ignoresMouseEvents` is toggled from global + local mouse monitors
/// (driven by `DockManager`) depending on whether the pointer is over the dock body.
@MainActor
final class DockPanelController {
    let dockID: UUID
    private(set) var dock: DockConfig
    private(set) var screen: NSScreen
    let panel: DockPanel

    private let hostingView: NSHostingView<DockPanelContent>
    private var layout: DockPanelLayout

    /// Ordered in (not suppressed by hidden state / manual mode / full screen).
    private(set) var isShown = false
    /// Auto-hide: slid off-screen.
    private(set) var isCollapsed = false
    /// Pointer is over the dock → panel accepts mouse events.
    private var mouseInside = false
    /// Revealed programmatically (shortcut/menu); uses a longer hide delay until the pointer visits.
    private var heldOpen = false
    private var revealTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var visibilityGeneration = 0

    var displayID: CGDirectDisplayID { screen.displayID }

    init(dock: DockConfig, screen: NSScreen) {
        let layout = DockPanelLayout(dock: dock, screen: screen)
        let content = DockPanelContent(dockID: dock.id, margin: layout.margin, edge: dock.edge)

        let panel = DockPanel(contentRect: layout.frame,
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered,
                              defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = true
        panel.worksWhenModal = true
        panel.tabbingMode = .disallowed

        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: layout.frame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        self.dockID = dock.id
        self.dock = dock
        self.screen = screen
        self.layout = layout
        self.panel = panel
        self.hostingView = hosting
        self.isCollapsed = dock.behavior.autoHide == .auto

        applyWindowSettings()
        panel.setFrame(currentTargetFrame, display: false)
    }

    // MARK: Configuration

    /// Re-applies config / screen; animates the frame change when visible.
    func update(dock newDock: DockConfig, screen newScreen: NSScreen) {
        let screenChanged = newScreen.displayID != screen.displayID
        let oldMode = dock.behavior.autoHide
        dock = newDock
        screen = newScreen
        applyWindowSettings()

        let newLayout = DockPanelLayout(dock: newDock, screen: newScreen)
        let content = DockPanelContent(dockID: dockID, margin: newLayout.margin, edge: newDock.edge)
        if content != hostingView.rootView { hostingView.rootView = content }
        layout = newLayout

        if oldMode != newDock.behavior.autoHide {
            cancelTimers()
            heldOpen = false
            isCollapsed = newDock.behavior.autoHide == .auto && !layout.engagedRect.contains(NSEvent.mouseLocation)
        }
        if isCollapsed {
            mouseInside = false
            setIgnoresMouse(true)
        }
        placeFrame(animated: isShown && !screenChanged)
    }

    private func applyWindowSettings() {
        let b = dock.behavior
        let level: NSWindow.Level = b.alwaysOnTop ? .floating : .normal
        if panel.level != level { panel.level = level }

        var collection: NSWindow.CollectionBehavior = [.ignoresCycle, .stationary]
        if b.showOnAllSpaces { collection.insert(.canJoinAllSpaces) }
        if !b.hideInFullScreen { collection.insert(.fullScreenAuxiliary) }
        if panel.collectionBehavior != collection { panel.collectionBehavior = collection }

        let appearance: NSAppearance?
        switch dock.appearance.mode {
        case .system: appearance = nil
        case .light: appearance = NSAppearance(named: .aqua)
        case .dark: appearance = NSAppearance(named: .darkAqua)
        }
        if panel.appearance?.name != appearance?.name { panel.appearance = appearance }
    }

    // MARK: Visibility

    func setShown(_ shown: Bool) {
        guard shown != isShown else { return }
        isShown = shown
        visibilityGeneration += 1
        let generation = visibilityGeneration

        if shown {
            if dock.behavior.autoHide == .auto {
                isCollapsed = !layout.engagedRect.contains(NSEvent.mouseLocation)
            } else {
                isCollapsed = false
            }
            panel.setFrame(currentTargetFrame, display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            animate({ self.panel.animator().alphaValue = self.targetAlpha }, completion: nil)
            handleMouse(at: NSEvent.mouseLocation)
        } else {
            cancelTimers()
            heldOpen = false
            mouseInside = false
            setIgnoresMouse(true)
            animate({ self.panel.animator().alphaValue = 0 }, completion: { [weak self] in
                guard let self, self.visibilityGeneration == generation, !self.isShown else { return }
                self.panel.orderOut(nil)
            })
        }
    }

    func close() {
        cancelTimers()
        isShown = false
        visibilityGeneration += 1
        panel.orderOut(nil)
        panel.close()
    }

    // MARK: Auto-hide

    /// Slides an auto-hide dock in. `holdOpen` (shortcut/menu reveal) keeps it open for at least
    /// 3 s even if the pointer is elsewhere.
    func expand(holdOpen: Bool) {
        cancelTimers()
        guard isShown, isCollapsed else { return }
        heldOpen = holdOpen
        isCollapsed = false
        placeFrame(animated: true)
        if holdOpen { scheduleHide(after: max(dock.behavior.hideDelay, 3)) }
    }

    /// Slides an auto-hide dock away (no-op for other modes).
    func collapse() {
        guard dock.behavior.autoHide == .auto, !isCollapsed else { return }
        cancelTimers()
        heldOpen = false
        isCollapsed = true
        mouseInside = false
        setIgnoresMouse(true)
        placeFrame(animated: isShown)
    }

    /// Called by `DockManager` for every pointer movement (global coordinates).
    func handleMouse(at p: NSPoint) {
        guard isShown else { return }

        let hot: Bool
        if isCollapsed {
            hot = false
        } else if mouseInside {
            hot = layout.activeRect.contains(p)
        } else {
            hot = layout.bodyRect.insetBy(dx: -2, dy: -2).contains(p)
        }
        mouseInside = hot
        setIgnoresMouse(!hot)

        guard dock.behavior.autoHide == .auto else { return }
        let locked = DockManager.shared.isInteractionLocked(dockID)

        if isCollapsed {
            let atEdge = layout.revealZones.contains { $0.contains(p) }
            if atEdge { scheduleReveal() } else { cancelReveal() }
        } else {
            let engaged = hot || layout.engagedRect.contains(p)
            if engaged { heldOpen = false }
            if engaged || locked {
                cancelHide()
            } else if hideTask == nil {
                scheduleHide(after: heldOpen ? max(dock.behavior.hideDelay, 3) : dock.behavior.hideDelay)
            }
        }
    }

    private func scheduleReveal() {
        guard revealTask == nil else { return }
        let delay = max(0, dock.behavior.revealDelay)
        revealTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.revealTask = nil
            let p = NSEvent.mouseLocation
            if self.isCollapsed, self.layout.revealZones.contains(where: { $0.contains(p) }) {
                self.expand(holdOpen: false)
                self.handleMouse(at: p)
            }
        }
    }

    private func scheduleHide(after delay: Double) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, delay)))
            guard let self, !Task.isCancelled else { return }
            self.hideTask = nil
            let p = NSEvent.mouseLocation
            if DockManager.shared.isInteractionLocked(self.dockID) { return }
            if self.mouseInside || self.layout.engagedRect.contains(p) { return }
            self.collapse()
        }
    }

    private func cancelReveal() {
        revealTask?.cancel()
        revealTask = nil
    }

    private func cancelHide() {
        hideTask?.cancel()
        hideTask = nil
    }

    private func cancelTimers() {
        cancelReveal()
        cancelHide()
    }

    // MARK: Frame

    private var currentTargetFrame: NSRect {
        isCollapsed ? layout.collapsedFrame : layout.frame
    }

    private var targetAlpha: CGFloat {
        (isCollapsed && layout.collapsedLeaksOntoOtherScreen) ? 0 : 1
    }

    private func placeFrame(animated: Bool) {
        let target = currentTargetFrame
        let alpha = targetAlpha
        let shown = isShown
        if animated {
            animate({
                if self.panel.frame != target { self.panel.animator().setFrame(target, display: true) }
                if shown { self.panel.animator().alphaValue = alpha }
            }, completion: nil)
        } else {
            panel.setFrame(target, display: true)
            if shown { panel.alphaValue = alpha }
        }
    }

    private var animationDuration: TimeInterval {
        0.26 * max(0, dock.appearance.animationSpeed)
    }

    private func animate(_ changes: @escaping () -> Void, completion: (() -> Void)?) {
        let duration = animationDuration
        guard duration > 0.001 else {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            changes()
            NSAnimationContext.endGrouping()
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            changes()
        }, completionHandler: {
            onMainActor { completion?() }
        })
    }

    private func setIgnoresMouse(_ ignore: Bool) {
        if panel.ignoresMouseEvents != ignore { panel.ignoresMouseEvents = ignore }
    }
}
