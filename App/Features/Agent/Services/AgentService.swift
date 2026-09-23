import Foundation

/// Runs the agent for one user request and reports progress as events.
///
/// This is the boundary between the interface and the AI runtime. The UI
/// depends only on this protocol so it can be driven by the real agent, by
/// `SimulatedAgentService`, or by a test stub (docs/decisions/0005-agent-runtime.md).
///
/// Cancellation: cancelling the consuming task terminates the stream, which
/// must cancel model streaming, any running tool and any pending approval.
protocol AgentService: Sendable {
    /// - Parameter approver: asked before any tool call that needs the user's
    ///   consent. The run waits for its answer.
    func run(_ request: AgentRunRequest, approver: any ToolApprover) -> AsyncThrowingStream<AgentEvent, Error>
}

/// Loads a project's agent instructions. Implemented in `Infrastructure`.
protocol ProjectInstructionsLoading: Sendable {
    func instructions(for projectRoot: URL) async -> [ProjectInstruction]
}
