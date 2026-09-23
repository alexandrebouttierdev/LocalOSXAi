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
    var messages: [AgentMessage]
}
