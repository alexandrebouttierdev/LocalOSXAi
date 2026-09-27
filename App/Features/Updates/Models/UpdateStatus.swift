import Foundation

/// Where the update check stands.
enum UpdateStatus: Hashable, Sendable {
    /// Not checked yet, or a check at launch failed (it stays silent).
    case idle
    case checking
    case upToDate
    case available(AppRelease)
    /// A check the user asked for failed; shown in the update window.
    case failed(UserFacingError)
}
