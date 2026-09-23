import Foundation

/// A tool call waiting for the user's decision.
struct ToolApprovalRequest: Identifiable, Hashable, Sendable {
    /// The tool call id.
    let id: String
    let toolName: String
    /// What the call will do, in one line (“Write Sources/App.swift (42 lines)”).
    let summary: String
    /// Why approval is needed (“This changes files in your project.”).
    let reason: String
    /// The change a file-writing call would make, shown as a diff before approving.
    var preview: Preview?

    struct Preview: Hashable, Sendable {
        let path: String
        let isNewFile: Bool
        let diff: FileDiff
    }
}

enum ToolApprovalDecision: Hashable, Sendable {
    case allowOnce
    /// Allow this tool without asking again for the rest of the session.
    case allowForSession
    case deny
}

/// Asks the user whether a tool call may run.
///
/// The agent runtime suspends while waiting, so implementations must answer
/// `.deny` when the waiting task is cancelled.
protocol ToolApprover: Sendable {
    func decide(_ request: ToolApprovalRequest) async -> ToolApprovalDecision
}
