import Foundation

/// An `AgentService` that streams a plain conversation with the selected
/// model, without tools.
///
/// Phase 2 deliverable: it exercises real providers end to end (discovery,
/// resolution, context budgeting, streaming, cancellation) through the same
/// `AgentEvent` contract the Phase 3 tool-using runtime will honor, which
/// will replace it. It depends only on `ModelResolving` and `LLMProvider`,
/// never on a concrete provider.
struct DirectChatAgentService: AgentService {
    private let resolver: any ModelResolving
    private let temperature: Double?

    init(resolver: any ModelResolving, temperature: Double? = nil) {
        self.resolver = resolver
        self.temperature = temperature
    }

    func run(_ request: AgentRunRequest) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await execute(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func execute(_ request: AgentRunRequest, continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation) async throws {
        guard let modelID = request.model else { throw AgentError.noModelSelected }
        guard let resolved = await resolver.resolve(modelID) else { throw AgentError.modelUnavailable(name: modelID.name) }

        let contextTokens = resolved.model.contextWindow.effectiveTokens
        let window = try ConversationWindow.fit(
            system: Self.systemPrompt(projectName: request.projectRoot.lastPathComponent),
            history: Self.history(from: request.history),
            prompt: request.prompt,
            budget: ConversationWindow.promptBudget(contextTokens: contextTokens)
        )
        continuation.yield(.contextUsageUpdated(ContextUsage(usedTokens: window.estimatedTokens, budgetTokens: contextTokens)))

        let llmRequest = LLMRequest(
            model: resolved.model.name,
            messages: window.messages,
            options: GenerationOptions(temperature: temperature, contextLength: contextTokens)
        )
        continuation.yield(.assistantMessageStarted(id: UUID()))
        for try await event in resolved.provider.stream(request: llmRequest) {
            switch event {
            case .textDelta(let text):
                continuation.yield(.textDelta(text))
            case .reasoningDelta(let text):
                continuation.yield(.reasoningDelta(text))
            case .usage(let usage):
                // Replace the estimate with what the server actually counted.
                continuation.yield(.contextUsageUpdated(ContextUsage(usedTokens: usage.totalTokens, budgetTokens: contextTokens)))
            case .toolCall, .finished:
                // No tools are offered, so tool calls cannot legitimately occur.
                break
            }
        }
        try Task.checkCancellation()
        continuation.yield(.finished(.completed))
    }

    /// Converts the transcript into model messages. Failed runs and error
    /// entries are left out: they are UI information, not conversation.
    static func history(from messages: [AgentMessage]) -> [LLMMessage] {
        messages.compactMap { message in
            switch message.role {
            case .user:
                return .user(message.text)
            case .assistant where message.state != .failed && !message.text.isEmpty:
                return .assistant(message.text)
            case .assistant, .error:
                return nil
            }
        }
    }

    static func systemPrompt(projectName: String) -> String {
        """
        You are a precise software engineering assistant working on the project “\(projectName)”.
        You cannot read, search or modify files, nor run commands, in this version: answer from \
        the conversation only, say clearly when you would need to inspect code, and never invent \
        file contents. Be concise and use Markdown code blocks for code.
        """
    }
}
