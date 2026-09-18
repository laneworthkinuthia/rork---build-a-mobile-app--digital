import Foundation
import UserNotifications

/// Minimum viable notifications for the beta: an authorization prompt plus
/// in-app banners for live events (new messages, requests, accepted requests).
/// APNs push for background delivery requires Apple Developer configuration
/// and is intentionally out of scope for this milestone.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private var isAuthorized = false

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in self.isAuthorized = granted }
        }
    }

    func notifyNewMessage(from name: String, text: String) {
        present(identifier: "message-\(UUID().uuidString)", title: name, body: text)
    }

    func notifyNewRequest(from name: String) {
        present(identifier: "request-\(UUID().uuidString)", title: "Cardex", body: "\(name) wants to connect with you.")
    }

    func notifyRequestAccepted(by name: String) {
        present(identifier: "accepted-\(UUID().uuidString)", title: "Cardex", body: "\(name) accepted your request — you're connected.")
    }

    private func present(identifier: String, title: String, body: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil,
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Show banners even while the app is in the foreground — without a
    /// backend push service this is the only visible surface for live events.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
