import Foundation
import ServiceManagement

/// "Open at login" via `SMAppService.mainApp` (requires running from a bundled Dox.app).
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// - Returns: `true` when the system state now matches `enabled`.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled || service.status == .requiresApproval { try service.unregister() }
            }
            return true
        } catch {
            NSLog("Dox: login item \(enabled ? "register" : "unregister") failed: \(error)")
            return false
        }
    }
}
