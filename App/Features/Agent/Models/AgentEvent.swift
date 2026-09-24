import Foundation

/// A progress event emitted by an agent run, consumed by the UI.
///
/// These events are the only contract between the agent runtime and the
/// interface, which is why any `AgentService` (real or simulated) can drive
/// the UI. Failures end the stream by throwing, never through an event.
enum AgentEvent: Sendable, Hashable {
    /// A new assistant message begins; following deltas and tool calls belong to it.
    case assistantMessageStarted(id: UUID)
    case textDelta(String)
    case reasoningDelta(String)
    /// The model is generating a tool call; its arguments keep growing.
    case toolCallPreparing(ToolCallDraft)
    case toolCallStarted(ToolCallRecord)
    /// A started call moved to another non-final state (awaiting approval, running).
    case toolCallStatusChanged(id: String, status: ToolCallRecord.Status)
    case toolCallFinished(id: String, status: ToolCallRecord.Status, summary: String, output: String)
    case contextUsageUpdated(ContextUsage)
    /// Instruction files loaded into the context, by relative path.
    case instructionsLoaded([String])
    /// Last event of a run that was not cancelled and did not throw.
    case finished(AgentRunOutcome)
}

/// How a run ended when it did not fail.
enum AgentRunOutcome: String, Sendable, Hashable {
    /// The model produced a final answer.
    case completed
    /// The run stopped at the configured iteration limit.
    case reachedIterationLimit
}

/// Everything an `AgentService` needs to start a run.
struct AgentRunRequest: Sendable, Hashable {
    let sessionID: UUID
    let projectRoot: URL
    /// The new user message.
    let prompt: String
    /// Transcript before `prompt`, oldest first.
    let history: [AgentMessage]
    let model: AIModel.ID?
    var options = AgentRunOptions()
}

/// Per-project and per-model settings applied to one run, read when the user
/// sends a message so a change applies to the next run.
struct AgentRunOptions: Sendable, Hashable {
    /// The project opted in to `CLAUDE.md`.
    var includesClaudeInstructions = false
    /// The project's command rules.
    var commandRules = CommandRules()
    /// Temperature, reasoning effort and context length chosen for the model.
    /// `contextLength` overrides the context the model would otherwise get.
    var generation = GenerationOptions()
}
