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
    /// Share of the prompt budget a run may start with before summarizing.
    var summaryStartRatio = HistoryCompaction.defaultStartRatio
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
        events { emit in try await execute(request, approver: approver, emit: emit) }
    }

    func compact(_ request: AgentCompactRequest) -> AsyncThrowingStream<AgentEvent, Error> {
        events { emit in try await executeCompaction(request, emit: emit) }
    }

    /// Runs `body` in a task that the stream's consumer cancels by stopping.
    private func events(
        _ body: @escaping @Sendable (_ emit: @escaping @Sendable (AgentEvent) -> Void) async throws -> Void
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await body { continuation.yield($0) }
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
                                           limits: limits, emit: emit)
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
                           options: generationOptions(request.options.generation, model: resolved.model,
                                                      contextTokens: contextTokens)),
                provider: resolved.provider, contextTokens: contextTokens, emit: emit
            )
            // A call cut by the length limit has truncated arguments: running
            // it could write half a file, and retrying hits the same limit.
            if response.finishReason == .length, !response.toolCalls.isEmpty {
                throw AgentError.toolCallCutOff(contextTokens: contextTokens)
            }
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
                            limits: AgentLimits, emit: @Sendable (AgentEvent) -> Void) async throws -> RunContext {
        var history = AgentPrompt.history(from: request.history)
        let prompt = AgentPrompt.userContent(request.prompt, attachments: request.attachments)
        if limits.summarizesHistory {
            history = try await summarizedIfNeeded(history, system: system, prompt: prompt, request: request,
                                                   resolved: resolved, contextTokens: contextTokens,
                                                   startRatio: limits.summaryStartRatio, emit: emit)
        }
        return RunContext(contextTokens: contextTokens, systemPrompt: AgentPrompt.system(system, summary: history.summary),
                          history: history.messages, prompt: prompt)
    }

    /// Replaces the oldest history with a summary written by the model when
    /// the run would start too full (`HistoryCompaction`).
    ///
    /// A failed or empty summary is not an error: the run continues with the
    /// history unchanged and the context manager drops the oldest messages,
    /// as it did before summaries existed. Only cancellation ends the run.
    /// - Parameter prompt: the new message as sent, with its attachments.
    private func summarizedIfNeeded(_ history: AgentPrompt.History, system: String, prompt: String, request: AgentRunRequest,
                                    resolved: ResolvedModel, contextTokens: Int, startRatio: Double,
                                    emit: @Sendable (AgentEvent) -> Void) async throws -> AgentPrompt.History {
        let count = HistoryCompaction.messagesToSummarize(
            history: history.messages,
            fixedTokens: TokenEstimator.estimate(messages: [system, prompt]),
            currentSummaryTokens: history.summary.map(TokenEstimator.estimate) ?? 0,
            promptBudget: RunContext.promptBudget(contextTokens: contextTokens),
            startRatio: startRatio
        )
        guard count > 0 else { return history }
        let id = UUID()
        emit(.historySummaryStarted(id: id, afterMessageID: history.entries[count - 1].messageID))
        do {
            let text = try await summary(of: history, count: count, resolved: resolved,
                                         generation: request.options.generation, contextTokens: contextTokens)
            emit(.historySummaryFinished(id: id, text: text))
            return AgentPrompt.History(summary: text, entries: Array(history.entries.dropFirst(count)))
        } catch {
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            Logger(category: .agent).error("History summary failed, dropping old messages instead: \(error)")
            emit(.historySummaryDiscarded(id: id))
            return history
        }
    }

    /// Summarizes the whole conversation at the user's request. Unlike the
    /// summary before a run, a failure is the result: it is reported.
    private func executeCompaction(_ request: AgentCompactRequest, emit: @Sendable (AgentEvent) -> Void) async throws {
        let history = AgentPrompt.history(from: request.history)
        guard let last = history.entries.last,
              history.entries.count >= HistoryCompaction.minimumSummarizedMessages else { throw AgentError.nothingToCompact }
        guard let modelID = request.model else { throw AgentError.noModelSelected }
        guard let resolved = await resolver.resolve(modelID) else { throw AgentError.modelUnavailable(name: modelID.name) }

        let contextTokens = resolved.model.contextWindow.effectiveTokens(choosing: request.options.generation.contextLength)
        let id = UUID()
        emit(.historySummaryStarted(id: id, afterMessageID: last.messageID))
        let text: String
        do {
            text = try await summary(of: history, count: history.entries.count, resolved: resolved,
                                     generation: request.options.generation, contextTokens: contextTokens)
        } catch {
            emit(.historySummaryDiscarded(id: id))
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            throw error
        }
        emit(.historySummaryFinished(id: id, text: text))

        // What the next run starts from before the new message: the system
        // prompt with the summary, since no earlier message is replayed.
        let instructions = await instructionsLoader.instructions(
            for: request.projectRoot, includingClaudeInstructions: request.options.includesClaudeInstructions
        )
        let system = AgentPrompt.system(projectName: request.projectRoot.lastPathComponent, instructions: instructions,
                                        toolsEnabled: resolved.model.supportsTools && !tools.isEmpty)
        let used = TokenEstimator.estimate(messages: [AgentPrompt.system(system, summary: text)])
        emit(.contextUsageUpdated(ContextUsage(usedTokens: used, budgetTokens: contextTokens)))
    }

    /// The model's summary of the first `count` history messages, folding in
    /// the summary they follow, shortened to `HistoryCompaction.summaryTokens`.
    ///
    /// - Throws: the provider's error, or `AgentError.emptyResponse`.
    private func summary(of history: AgentPrompt.History, count: Int, resolved: ResolvedModel,
                         generation: GenerationOptions, contextTokens: Int) async throws -> String {
        let budget = RunContext.promptBudget(contextTokens: contextTokens)
        let summaryTokens = HistoryCompaction.summaryTokens(promptBudget: budget)
        let messages = AgentPrompt.summaryRequest(previousSummary: history.summary,
                                                  messages: Array(history.messages.prefix(count)),
                                                  maxInputTokens: budget, maxSummaryTokens: summaryTokens)
        var text = ""
        let llmRequest = LLMRequest(model: resolved.model.name, messages: messages,
                                    options: generationOptions(generation, model: resolved.model, contextTokens: contextTokens))
        for try await event in resolved.provider.stream(request: llmRequest) {
            if case .textDelta(let delta) = event { text += delta }
        }
        try Task.checkCancellation()
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AgentError.emptyResponse }
        // A model that ignores the length asked for must not crowd out the run.
        return OutputLimiter.limit(text, maxCharacters: summaryTokens * TokenEstimator.charactersPerToken,
                                   note: "summary shortened to save context")
    }

    /// The tool executor for one run, with the project's command rules.
    private func makeExecutor(commandRules: CommandRules, limits: AgentLimits) -> ToolExecutor {
        var policy = policy
        policy.commandRules = commandRules
        return ToolExecutor(registry: tools, policy: policy, timeout: limits.toolTimeout,
                            maxOutputCharacters: limits.maxToolOutputCharacters)
    }

    /// The model settings for this run, with the context length the budget uses and a cap on
    /// the answer so a model that ignores the "write in several steps" instruction fails fast
    /// (`toolCallCutOff`/`outputLimitReached`) instead of generating silently until the
    /// provider's idle timeout (docs/ai/context.md § Budget, ADR 0029).
    ///
    /// No cap when the context is only the fallback guess: a model its runtime loads on demand
    /// may get far more room, and a cap derived from the guess would cut a file it can write.
    private func generationOptions(_ chosen: GenerationOptions, model: AIModel, contextTokens: Int) -> GenerationOptions {
        var options = chosen
        options.contextLength = contextTokens
        if options.maxOutputTokens == nil, model.contextWindow.isEffectiveSizeKnown(choosing: chosen.contextLength) {
            options.maxOutputTokens = RunContext.outputReserve(contextTokens: contextTokens)
        }
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
