import Foundation
@testable import LocalOSXAi

/// A `UserNotifying` that records what would be shown or played.
@MainActor
final class RecordingNotifier: UserNotifying {
    private(set) var posted: [UserNotification] = []
    private(set) var soundCount = 0
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

    /// Acts as a click on a notification of `sessionID`.
    func click(_ sessionID: UUID) {
        openHandler?(sessionID)
    }
}
