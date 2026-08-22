import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    static let shared = LoginItemController()

    @Published private(set) var isEnabled = false
    @Published private(set) var statusMessage = "Checking…"

    private let defaults = UserDefaults.standard
    private let preferenceKey = "launchAtLogin"
    private let service = SMAppService.mainApp

    private init() {
        refresh()
    }

    func enableByDefaultIfNeeded() {
        if defaults.object(forKey: preferenceKey) == nil {
            defaults.set(true, forKey: preferenceKey)
        }

        guard defaults.bool(forKey: preferenceKey) else {
            refresh()
            return
        }

        switch service.status {
        case .notRegistered, .notFound:
            setEnabled(true)
        default:
            refresh()
        }
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: preferenceKey)
        do {
            if enabled {
                if service.status == .notRegistered || service.status == .notFound {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        switch service.status {
        case .enabled:
            isEnabled = true
            statusMessage = "Enabled"
        case .requiresApproval:
            isEnabled = false
            statusMessage = "Approval required"
        case .notRegistered:
            isEnabled = false
            statusMessage = "Off"
        case .notFound:
            isEnabled = false
            statusMessage = "Move Aperture to Applications first"
        @unknown default:
            isEnabled = false
            statusMessage = "Unavailable"
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
