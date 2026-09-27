import Foundation

/// Posts system notifications and sounds. Implemented in `Infrastructure`
/// with the User Notifications framework; tests use a recorder.
@MainActor
protocol UserNotifying: AnyObject {
    /// Asks for permission the first time, then posts. Never throws: a
    /// notification the user declined is simply not shown.
    func post(_ notification: UserNotification) async
    /// A short sound, for a session the user is looking at.
    func playSound()
    /// Called with the session of a notification the user clicked.
    func setOpenHandler(_ handler: @escaping @MainActor (UUID) -> Void)
}
