import AppKit
import Observation
import DoxCore

/// Tracks which apps are running / frontmost, for dock running indicators.
@MainActor
@Observable
final class RunningAppsMonitor {
    static let shared = RunningAppsMonitor()

    private(set) var runningBundleIDs: Set<String> = []
    private(set) var activeBundleID: String?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var bundleIDByPath: [String: String] = [:]

    private init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                onMainActor { self?.refresh() }
            }
            observers.append(token)
        }
    }

    private func refresh() {
        let apps = NSWorkspace.shared.runningApplications
        let ids = Set(apps.filter { $0.activationPolicy != .prohibited }.compactMap(\.bundleIdentifier))
        if ids != runningBundleIDs { runningBundleIDs = ids }
        let active = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if active != activeBundleID { activeBundleID = active }
    }

    /// Bundle id for an app item (stored id, else read from the bundle at its path).
    func bundleID(for item: DockItem) -> String? {
        guard case .app(let path, let stored) = item.kind else { return nil }
        if let stored, !stored.isEmpty { return stored }
        if let cached = bundleIDByPath[path] { return cached }
        guard let id = Bundle(path: path)?.bundleIdentifier else { return nil }
        bundleIDByPath[path] = id
        return id
    }

    func isRunning(_ item: DockItem) -> Bool {
        guard let id = bundleID(for: item) else { return false }
        return runningBundleIDs.contains(id)
    }

    func isActive(_ item: DockItem) -> Bool {
        guard let id = bundleID(for: item) else { return false }
        return activeBundleID == id
    }
}
