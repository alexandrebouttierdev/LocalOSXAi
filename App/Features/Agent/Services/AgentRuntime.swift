import Foundation
import OSLog

/// Limits that keep a run bounded and predictable.
struct AgentLimits: Hashable, Sendable {
    /// Model calls per run.
    var maxIterations = 25
    var toolTimeout: Duration = .seconds(30)
    /// Consecutive iterations in which every tool call was invalid.
    var maxConsecutiveInvalidIterations = 3
    /// Characters of a single tool result sent to the model.
    var maxToolOutputCharacters = 16_000
    /// Summarize earlier conversation before a run that starts too full
    /// (`HistoryCompaction`); otherwise the oldest messages are only dropped.
    var summarizesHistory = true
}

/// The agent loop: model → tool calls → tool results → model, until the
/// model answers without calling tools.
///
/// Provider-agnostic: it only sees `ModelResolving`, `LLMProvider` and the
/// model's abstract capabilities (docs/ai/agent.md). Tools run sequentially,
/// in the order the model requested them, so approvals and file changes
/// happen one at a time and in a predictable order.
struct AgentRuntime: AgentService {
    private let resolver: any ModelResolving
    private let tools: ToolRegistry
    private let instructionsLoader: any ProjectInstructionsLoading
    private let policy: ToolPermissionPolicy
    /// Read at the start of each run, so a Settings change applies to the next run.
    private let limits: @Sendable () -> AgentLimits
    private let changeRecorder: (any FileChangeRecording)?

    init(resolver: any ModelResolving, tools: ToolRegistry, instructionsLoader: any ProjectInstructionsLoading,
         policy: ToolPermissionPolicy = ToolPermissionPolicy(), limits: @escaping @Sendable () -> AgentLimits,
         changeRecorder: (any FileChangeRecording)? = nil) {
        self.resolver = resolver
        self.tools = tools
        self.instructionsLoader = instructionsLoader
        self.policy = policy
        self.limits = limits
        self.changeRecorder = changeRecorder
    }

    init(resolver: any ModelResolving, tools: ToolRegistry, instructionsLoader: any ProjectInstructionsLoading,
         policy: ToolPermissionPolicy = ToolPermissionPolicy(), limits: AgentLimits = AgentLimits(),
         changeRecorder: (any FileChangeRecording)? = nil) {
        self.init(resolver: resolver, tools: tools, instructionsLoader: instructionsLoader, policy: policy,
                  limits: { limits }, changeRecorder: changeRecorder)
    }

    func run(_ request: AgentRunRequest, approver: any ToolApprover) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await execute(request, approver: approver, emit: { continuation.yield($0) })
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func execute(_ request: AgentRunRequest, approver: any ToolApprover,
                         emit: @escaping @Sendable (AgentEvent) -> Void) async throws {
        guard let modelID = request.model else { throw AgentError.noModelSelected }
        guard let resolved = await resolver.resolve(modelID) else { throw AgentError.modelUnavailable(name: modelID.name) }

        let limits = limits()
        let toolsEnabled = resolved.model.supportsTools && !tools.isEmpty
        let instructions = await instructionsLoader.instructions(
            for: request.projectRoot, includingClaudeInstructions: request.options.includesClaudeInstructions
        )
        if !instructions.isEmpty { emit(.instructionsLoaded(instructions.map(\.source))) }

        let contextTokens = resolved.model.contextWindow.effectiveTokens(choosing: request.options.generation.contextLength)
        let system = AgentPrompt.system(projectName: request.projectRoot.lastPathComponent,
                                        instructions: instructions, toolsEnabled: toolsEnabled)
        var context = try await runContext(system: system, request: request, resolved: resolved, contextTokens: contextTokens,
                                           summarizes: limits.summarizesHistory, emit: emit)
        let executor = makeExecutor(commandRules: request.options.commandRules, limits: limits)
        let toolContext = ToolContext(projectRoot: request.projectRoot, changeRecorder: changeRecorder)
        var consecutiveInvalidIterations = 0

        for _ in 0..<limits.maxIterations {
            try Task.checkCancellation()
            let (messages, estimated) = try context.fittedMessages()
            emit(.contextUsageUpdated(ContextUsage(usedTokens: estimated, budgetTokens: contextTokens)))

            let response = try await streamResponse(
                LLMRequest(model: resolved.model.name, messages: messages,
                           tools: toolsEnabled ? tools.definitions : [],
                           options: generationOptions(request.options.generation, contextTokens: contextTokens)),
                provider: resolved.provider, contextTokens: contextTokens, emit: emit
            )
            context.appendAssistant(text: response.text, toolCalls: response.toolCalls)
            guard !response.toolCalls.isEmpty else {
                // A silent end would look like a hang: say why nothing came back.
                if response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw response.finishReason == .length ? AgentError.outputLimitReached : AgentError.emptyResponse
                }
                emit(.finished(.completed))
                return
            }

            var invalidCalls = 0
            for call in response.toolCalls {
                let outcome = try await runTool(call, executor: executor, toolContext: toolContext, approver: approver, emit: emit)
                context.appendToolResult(outcome.output, callID: call.id, toolName: call.name)
                if outcome.isInvalidCall { invalidCalls += 1 }
            }
            consecutiveInvalidIterations = invalidCalls == response.toolCalls.count ? consecutiveInvalidIterations + 1 : 0
            if consecutiveInvalidIterations >= limits.maxConsecutiveInvalidIterations {
                throw AgentError.tooManyInvalidToolCalls(count: consecutiveInvalidIterations)
            }
        }
        emit(.finished(.reachedIterationLimit))
    }

    /// The run's starting context: system prompt, earlier conversation
    /// (summarized first when needed) and the new request.
    private func runContext(system: String, request: AgentRunRequest, resolved: ResolvedModel, contextTokens: Int,
                            summarizes: Bool, emit: @Sendable (AgentEvent) -> Void) async throws -> RunContext {
        var history = AgentPrompt.history(from: request.history)
        if summarizes {
            history = try await summarizedIfNeeded(history, system: system, request: request, resolved: resolved,
                                                   contextTokens: contextTokens, emit: emit)
        }
        return RunContext(contextTokens: contextTokens, systemPrompt: AgentPrompt.system(system, summary: history.summary),
                          history: history.messages, prompt: request.prompt)
    }

    /// Replaces the oldest history with a summary written by the model when
    /// the run would start too full (`HistoryCompaction`).
    ///
    /// A failed or empty summary is not an error: the run continues with the
    /// history unchanged and the context manager drops the oldest messages,
    /// as it did before summaries existed. Only cancellation ends the run.
    private func summarizedIfNeeded(_ history: AgentPrompt.History, system: String, request: AgentRunRequest,
                                    resolved: ResolvedModel, contextTokens: Int,
                                    emit: @Sendable (AgentEvent) -> Void) async throws -> AgentPrompt.History {
        let budget = RunContext.promptBudget(contextTokens: contextTokens)
        let count = HistoryCompaction.messagesToSummarize(
            history: history.messages,
            fixedTokens: TokenEstimator.estimate(messages: [system, request.prompt]),
            currentSummaryTokens: history.summary.map(TokenEstimator.estimate) ?? 0,
            promptBudget: budget
        )
        guard count > 0 else { return history }
        let summaryTokens = HistoryCompaction.summaryTokens(promptBudget: budget)
        let id = UUID()
        emit(.historySummaryStarted(id: id, afterMessageID: history.entries[count - 1].messageID))
        do {
            let messages = AgentPrompt.summaryRequest(previousSummary: history.summary,
                                                      messages: Array(history.messages.prefix(count)),
                                                      maxInputTokens: budget, maxSummaryTokens: summaryTokens)
            var options = request.options.generation
            options.contextLength = contextTokens
            var text = ""
            for try await event in resolved.provider.stream(request: LLMRequest(model: resolved.model.name, messages: messages,
                                                                                 options: options)) {
                if case .textDelta(let delta) = event { text += delta }
            }
            try Task.checkCancellation()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw AgentError.emptyResponse }
            // A model that ignores the length asked for must not crowd out the run.
            let limit = summaryTokens * TokenEstimator.charactersPerToken
            text = OutputLimiter.limit(text, maxCharacters: limit, note: "summary shortened to save context")
            emit(.historySummaryFinished(id: id, text: text))
            return AgentPrompt.History(summary: text, entries: Array(history.entries.dropFirst(count)))
        } catch {
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            Logger(category: .agent).error("History summary failed, dropping old messages instead: \(error)")
            emit(.historySummaryDiscarded(id: id))
            return history
        }
    }

    /// The tool executor for one run, with the project's command rules.
    private func makeExecutor(commandRules: CommandRules, limits: AgentLimits) -> ToolExecutor {
        var policy = policy
        policy.commandRules = commandRules
        return ToolExecutor(registry: tools, policy: policy, timeout: limits.toolTimeout,
                            maxOutputCharacters: limits.maxToolOutputCharacters)
    }

    /// The model settings for this run, with the context length the budget uses.
    private func generationOptions(_ chosen: GenerationOptions, contextTokens: Int) -> GenerationOptions {
        var options = chosen
        options.contextLength = contextTokens
        return options
    }

    /// Runs one tool call, reporting its progress; a cancelled call ends the run.
    private func runTool(_ call: LLMToolCall, executor: ToolExecutor, toolContext: ToolContext,
                         approver: any ToolApprover,
                         emit: @escaping @Sendable (AgentEvent) -> Void) async throws -> ToolExecutor.Outcome {
        try Task.checkCancellation()
        emit(.toolCallStarted(ToolCallRecord(id: call.id, name: call.name, argumentsJSON: call.rawArguments, status: .running)))
        let outcome = await executor.execute(call, context: toolContext, approver: approver) { status in
            emit(.toolCallStatusChanged(id: call.id, status: status))
        }
        guard outcome.status != .cancelled else { throw CancellationError() }
        emit(.toolCallFinished(id: call.id, status: outcome.status, summary: outcome.summary, output: outcome.output))
        return outcome
    }

    private struct ModelResponse {
        var text = ""
        var toolCalls: [LLMToolCall] = []
        var finishReason: FinishReason?
    }

    /// Streams one model response, forwarding text and reasoning as they arrive.
    private func streamResponse(_ llmRequest: LLMRequest, provider: any LLMProvider, contextTokens: Int,
                                emit: @Sendable (AgentEvent) -> Void) async throws -> ModelResponse {
        emit(.assistantMessageStarted(id: UUID()))
        var response = ModelResponse()
        for try await event in provider.stream(request: llmRequest) {
            switch event {
            case .textDelta(let text):
                response.text += text
                emit(.textDelta(text))
            case .reasoningDelta(let text):
                emit(.reasoningDelta(text))
            case .toolCall(let call):
                response.toolCalls.append(call)
            case .toolCallProgress(let progress):
                emit(.toolCallPreparing(ToolCallDraft(
                    name: progress.name,
                    path: PartialJSON.string(forKey: "path", in: progress.argumentsPrefix),
                    characters: progress.characters
                )))
            case .usage(let usage):
                // Replace the estimate with what the server actually counted.
                emit(.contextUsageUpdated(ContextUsage(usedTokens: usage.totalTokens, budgetTokens: contextTokens)))
                emit(.usage(usage))
            case .finished(let reason):
                response.finishReason = reason
            }
        }
        try Task.checkCancellation()
        return response
    }
}
