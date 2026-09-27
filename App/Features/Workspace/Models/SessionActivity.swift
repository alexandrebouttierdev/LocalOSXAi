import Foundation

/// What a session's agent is doing, shown next to the session in the sidebar
/// so work in another session is never forgotten.
enum SessionActivity: Hashable, Sendable {
    /// A run is in progress.
    case running
    /// A run is waiting for the user to allow or deny a tool call.
    case awaitingApproval
}
