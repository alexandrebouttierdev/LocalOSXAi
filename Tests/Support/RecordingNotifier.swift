import Foundation
@testable import LocalOSXAi

/// A `UserNotifying` that records what would be shown or played.
@MainActor
final class RecordingNotifier: UserNotifying {
    private(set) var posted: [UserNotification] = []
    private(set) var soundCount = 0
    private(set) var permissionRequests = 0
    private(set) var openedSystemSettings = false
    /// What the user answers to the permission prompt.
    var answer = NotificationPermission.allowed
    var currentPermission = NotificationPermission.notDetermined
    private var openHandler: (@MainActor (UUID) -> Void)?

    func post(_ notification: UserNotification) async {
        posted.append(notification)
    }

    func playSound() {
        soundCount += 1
    }

    func setOpenHandler(_ handler: @escaping @MainActor (UUID) -> Void) {
        openHandler = handler
    }

    func permission() async -> NotificationPermission {
        currentPermission
    }

    func requestPermission() async -> NotificationPermission {
        permissionRequests += 1
        if currentPermission == .notDetermined { currentPermission = answer }
        return currentPermission
    }

    func openSystemSettings() {
        openedSystemSettings = true
    }

    /// Acts as a click on a notification of `sessionID`.
    func click(_ sessionID: UUID) {
        openHandler?(sessionID)
    }
}
