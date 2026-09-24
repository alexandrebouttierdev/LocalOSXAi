import Foundation

/// A conversation with the agent inside one project.
///
/// Sessions depend on the Agent feature's `AgentMessage`; the Agent feature
/// does not depend on sessions (it receives a persistence closure instead),
/// which keeps the dependency between the two features one-directional.
struct Session: Identifiable, Hashable, Sendable, Codable {
    static let defaultTitle = "New session"

    let id: UUID
    let projectID: Project.ID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    /// Model used by the latest run, remembered so the session resumes with it.
    var model: AIModel.ID?
    /// The transcript. Empty in the summaries that session lists return:
    /// only `SessionRepository.session(id:)` loads it (docs/data/persistence.md).
    var messages: [AgentMessage]
    /// Tool calls made across the session, shown as sidebar metadata. Stored
    /// so lists can show it without loading transcripts.
    var toolCallCount = 0

    /// The session without its transcript, as lists return it.
    var summary: Session {
        var summary = self
        summary.messages = []
        return summary
    }

    static func toolCallCount(in messages: [AgentMessage]) -> Int {
        messages.reduce(0) { $0 + $1.toolCalls.count }
    }
}
