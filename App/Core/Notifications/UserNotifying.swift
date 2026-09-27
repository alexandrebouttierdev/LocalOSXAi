import Foundation

/// A system notification: a session that needs the user, or a test.
struct UserNotification: Hashable, Sendable {
    /// The session to open when it is clicked; `nil` for a test notification.
    let sessionID: UUID?
    /// The session's title.
    let title: String
    /// The project's name.
    let subtitle: String
    let body: String
    let playsSound: Bool

    /// Characters of an answer shown in a notification.
    static let previewLength = 180
}

/// The user's choices in Settings › General, read each time a session needs them.
struct NotificationPreferences: Hashable, Sendable {
    var showsNotifications = true
    var playsSound = true
}

/// Whether macOS lets the app show notifications.
enum NotificationPermission: Hashable, Sendable {
    /// The user was never asked.
    case notDetermined
    case allowed
    /// Turned off in System Settings › Notifications.
    case denied
}

/// Posts system notifications and sounds. Implemented in `Infrastructure`
/// with the User Notifications framework; tests use a recorder.
@MainActor
protocol UserNotifying: AnyObject {
    /// Posts if allowed. Never throws: a notification the user declined is
    /// simply not shown.
    func post(_ notification: UserNotification) async
    /// A short sound, for a session the user is looking at.
    func playSound()
    /// Called with the session of a notification the user clicked.
    func setOpenHandler(_ handler: @escaping @MainActor (UUID) -> Void)
    func permission() async -> NotificationPermission
    /// Shows the system prompt if the user was never asked, then returns the
    /// permission; asks nothing otherwise.
    func requestPermission() async -> NotificationPermission
    /// Opens the app's page in System Settings › Notifications.
    func openSystemSettings()
}
