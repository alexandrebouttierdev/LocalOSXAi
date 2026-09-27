import AppKit
import OSLog
import UserNotifications

/// Posts notifications with the User Notifications framework and plays the
/// system's short sound.
///
/// Permission is asked with the first notification rather than at launch,
/// so the prompt comes when the user can see why. A declined or failed
/// notification is only logged: it must never disturb a run.
///
/// Concurrency: the delegate callbacks are nonisolated. They only read a
/// Sendable value (the session id) before hopping to the main actor.
@MainActor
final class SystemUserNotifier: NSObject, UserNotifying, UNUserNotificationCenterDelegate {
    private nonisolated static let sessionIDKey = "sessionID"
    /// A short system sound, quieter than the alert sound.
    private static let soundName = NSSound.Name("Tink")
    private var openHandler: (@MainActor (UUID) -> Void)?

    override init() {
        super.init()
        // Set before launch finishes, so a click that launched the app is delivered.
        UNUserNotificationCenter.current().delegate = self
    }

    func post(_ notification: UserNotification) async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.subtitle = notification.subtitle
            content.body = notification.body
            content.sound = notification.playsSound ? .default : nil
            // Groups a session's notifications together in Notification Center.
            content.threadIdentifier = notification.sessionID.uuidString
            content.userInfo = [Self.sessionIDKey: notification.sessionID.uuidString]
            try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        } catch {
            Logger(category: .ui).error("Notification not posted: \(error)")
        }
    }

    func playSound() {
        NSSound(named: Self.soundName)?.play()
    }

    func setOpenHandler(_ handler: @escaping @MainActor (UUID) -> Void) {
        openHandler = handler
    }

    private func open(_ sessionID: UUID) {
        NSApp.activate()
        openHandler?(sessionID)
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Shown even while the app is frontmost: the workspace only posts for a
    /// session the user is not looking at.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let text = response.notification.request.content.userInfo[Self.sessionIDKey] as? String
        guard let sessionID = text.flatMap(UUID.init(uuidString:)) else { return }
        await open(sessionID)
    }
}
