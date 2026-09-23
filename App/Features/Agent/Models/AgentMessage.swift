import Foundation

/// One entry of a session transcript, as displayed and persisted.
///
/// This is the application's conversation model, distinct from `LLMMessage`
/// (the wire-level model sent to providers). The context manager derives
/// `LLMMessage`s from it; it is never sent to a provider directly.
struct AgentMessage: Identifiable, Hashable, Sendable, Codable {
    enum Role: String, Hashable, Sendable, Codable {
        case user
        case assistant
        /// A run failure shown inline in the transcript.
        case error
    }

    enum State: String, Hashable, Sendable, Codable {
        case complete
        case streaming
        case cancelled
        case failed
    }

    let id: UUID
    let role: Role
    var text: String
    /// Model reasoning (“thinking”) when the model exposes it.
    var reasoning: String
    /// Tool calls made while producing this assistant message, in order.
    var toolCalls: [ToolCallRecord]
    var state: State
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, reasoning: String = "", toolCalls: [ToolCallRecord] = [],
         state: State = .complete, createdAt: Date) {
        self.id = id
        self.role = role
        self.text = text
        self.reasoning = reasoning
        self.toolCalls = toolCalls
        self.state = state
        self.createdAt = createdAt
    }
}

/// A tool invocation as shown in the transcript: what was called, with which
/// arguments, and how it ended.
struct ToolCallRecord: Identifiable, Hashable, Sendable, Codable {
    enum Status: String, Hashable, Sendable, Codable {
        case awaitingApproval
        case running
        case succeeded
        case failed
        case denied
        case cancelled

        var isFinished: Bool { self != .awaitingApproval && self != .running }
    }

    let id: String
    let name: String
    let argumentsJSON: String
    var status: Status
    /// One-line human summary of the result.
    var summary: String?
    /// Full output returned to the model.
    var output: String?
}
