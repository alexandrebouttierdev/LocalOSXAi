import Foundation

/// Runs the agent for one user request and reports progress as events.
///
/// This is the boundary between the interface and the AI runtime. The UI
/// depends only on this protocol so it can be driven by the real agent, by
/// `SimulatedAgentService`, or by a test stub (docs/decisions/0005-agent-runtime.md).
///
/// Cancellation: cancelling the consuming task terminates the stream, which
/// must cancel model streaming and any running tool.
protocol AgentService: Sendable {
    func run(_ request: AgentRunRequest) -> AsyncThrowingStream<AgentEvent, Error>
}
