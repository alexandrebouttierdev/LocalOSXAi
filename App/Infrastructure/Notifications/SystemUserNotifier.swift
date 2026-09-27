import AppKit
import OSLog
import UserNotifications

/// Posts notifications with the User Notifications framework and plays the
/// system's short sound.
///
/// Permission is asked at launch while notifications are on (the workspace
/// calls `requestPermission()`), so the macOS prompt appears while the user
/// is in the app rather than, easy to miss, when a run ends in the
/// background. A declined or failed notification is only logged: it must
/// never disturb a run.
///
/// Concurrency: the delegate callbacks are nonisolated. They only read a
/// Sendable value (the session id) before hopping to the main actor.
@MainActor
final class SystemUserNotifier: NSObject, UserNotifying, UNUserNotificationCenterDelegate {
    nonisolated private static let sessionIDKey = "sessionID"
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
            guard await requestPermission() == .allowed else {
                Logger(category: .ui).info("Notification not posted: not allowed in System Settings")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.subtitle = notification.subtitle
            content.body = notification.body
            content.sound = notification.playsSound ? .default : nil
            if let sessionID = notification.sessionID {
                // Groups a session's notifications together in Notification Center.
                content.threadIdentifier = sessionID.uuidString
                content.userInfo = [Self.sessionIDKey: sessionID.uuidString]
            }
            try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        } catch {
            Logger(category: .ui).error("Notification not posted: \(error)")
        }
    }

    func permission() async -> NotificationPermission {
        Self.permission(from: await Self.authorizationStatus())
    }

    /// Nonisolated, so the non-Sendable settings object never crosses to the
    /// main actor: only the status does.
    nonisolated private static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestPermission() async -> NotificationPermission {
        let current = await permission()
        guard current == .notDetermined else { return current }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return granted ? .allowed : .denied
        } catch {
            Logger(category: .ui).error("Notification permission request failed: \(error)")
            return .notDetermined
        }
    }

    func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        let page = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")
        if let page { NSWorkspace.shared.open(page) }
    }

    private static func permission(from status: UNAuthorizationStatus) -> NotificationPermission {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .allowed
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
