import Foundation
import UserNotifications

struct ApertureNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
    let date = Date()
}

@MainActor
final class ApertureNotificationCenter: ObservableObject {
    static let shared = ApertureNotificationCenter()

    @Published private(set) var notices: [ApertureNotice] = []
    @Published private(set) var authorizationLabel = "Not requested"

    private init() {}

    func refreshAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationLabel = switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral: "Allowed"
                case .denied: "Disabled in System Settings"
                case .notDetermined: "Not requested"
                @unknown default: "Unknown"
                }
            }
        }
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.authorizationLabel = granted ? "Allowed" : "Disabled in System Settings"
            }
        }
    }

    func post(title: String, body: String, system: Bool = true) {
        notices.insert(ApertureNotice(title: title, body: body), at: 0)
        if notices.count > 24 { notices.removeLast(notices.count - 24) }
        guard system else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    Self.deliver(title: title, body: body)
                }
            } else if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                Self.deliver(title: title, body: body)
            }
        }
    }

    func clear() {
        notices.removeAll()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private nonisolated static func deliver(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

