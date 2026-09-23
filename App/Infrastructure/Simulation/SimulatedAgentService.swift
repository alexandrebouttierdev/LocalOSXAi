import Foundation

/// A scripted `AgentService` that streams a plausible run without any model.
///
/// It exists for two reasons (docs/decisions/0005-agent-runtime.md):
/// 1. it proves the UI is independent of the AI runtime — the whole interface
///    runs on it until the real agent lands in Phase 3;
/// 2. it gives previews and manual UI testing a deterministic session.
///
/// It never touches the filesystem: the tool call it shows is simulated.
struct SimulatedAgentService: AgentService {
    /// Delay between streamed chunks. Zero in tests.
    var chunkDelay: Duration = .milliseconds(18)
    var contextBudget = ContextWindow.fallbackTokens

    func run(_ request: AgentRunRequest) -> AsyncThrowingStream<AgentEvent, Error> {
        let script = Self.script(for: request)
        let delay = chunkDelay
        let usage = ContextUsage(
            usedTokens: TokenEstimator.estimate(messages: request.history.map(\.text) + [request.prompt]),
            budgetTokens: contextBudget
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.contextUsageUpdated(usage))
                    for event in script {
                        try await Task.sleep(for: delay)
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func script(for request: AgentRunRequest) -> [AgentEvent] {
        let callID = "simulated-\(UUID().uuidString.prefix(8))"
        var events: [AgentEvent] = [.assistantMessageStarted(id: UUID())]
        events += words("The user wants help with: \(request.prompt). I'll look at the project structure first.")
            .map(AgentEvent.reasoningDelta)
        events.append(.toolCallStarted(ToolCallRecord(
            id: callID, name: "list_directory", argumentsJSON: #"{"path":"."}"#, status: .running
        )))
        events.append(.toolCallFinished(
            id: callID,
            status: .succeeded,
            summary: "Simulated result",
            output: "This is a simulated tool result. Real filesystem tools arrive in Phase 3."
        ))
        let answer = """
            This is a simulated session running in \(request.projectRoot.lastPathComponent). \
            No model was called and no file was read or changed.

            The interface is driven by the same event stream the real agent will produce, \
            so conversation, tool calls, cancellation and context tracking can be exercised \
            before Ollama and LM Studio are connected in Phase 2.
            """
        events += words(answer).map(AgentEvent.textDelta)
        events.append(.finished(.completed))
        return events
    }

    /// Splits text into word-sized chunks, keeping separators, to mimic token streaming.
    private static func words(_ text: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == " " || character == "\n" {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
