import Foundation

/// Why a session needs the user, reported by `AgentViewModel` so the
/// workspace can notify them when they are not looking at it.
///
/// A run the user stopped is not reported: they are already there.
enum AgentAttention: Hashable, Sendable {
    /// The run ended with an answer; `preview` is its beginning.
    case answered(preview: String)
    case pausedAtStepLimit
    case failed(message: String)
    /// A tool call waits for the user's decision.
    case approvalNeeded(summary: String)
}
