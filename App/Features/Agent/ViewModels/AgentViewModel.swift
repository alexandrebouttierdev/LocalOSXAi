import Foundation
import Observation

/// State and actions of the conversation for one session.
///
/// Depends only on `AgentService`, so the same view model drives the real
/// agent, the simulated agent and test stubs. Transcript rules live in
/// `TranscriptReducer`; this type only orchestrates the run lifecycle and
/// answers tool approval requests on behalf of the user.
@MainActor
@Observable
final class AgentViewModel: ToolApprover {
    enum RunState: Equatable {
        case idle
        case running
        /// The model is summarizing the session at the user's request.
        case compacting
    }

    let sessionID: UUID
    let projectID: UUID?
    private(set) var messages: [AgentMessage]
    private(set) var runState: RunState = .idle
    private(set) var contextUsage: ContextUsage?
    /// What VoiceOver should announce about the last run: its end, not every
    /// token (docs/ui/accessibility.md). The view posts it when it changes.
    private(set) var announcement: Announcement?
    /// Instruction files the last run loaded (e.g. `AGENTS.md`).
    private(set) var instructionSources: [String] = []
    /// The tool call currently waiting for the user's decision.
    private(set) var pendingApproval: ToolApprovalRequest?
    /// Tools the user allowed for the rest of this session.
    private(set) var toolsAllowedForSession: Set<String> = []
    /// Why the last “Compact session” failed, until the next compaction or run.
    /// Not a transcript entry: it would make the last message retryable.
    private(set) var compactionError: UserFacingError?
    var draft = ""

    /// A run or a compaction is in progress: nothing else can start, and ⌘. stops it.
    var isRunning: Bool { runState != .idle }
    var isCompacting: Bool { runState == .compacting }

    /// The conversation since the latest summary holds at least one exchange,
    /// which is the least a summary is worth a model call for.
    var canCompact: Bool {
        !isRunning && AgentPrompt.history(from: messages).entries.count >= HistoryCompaction.minimumSummarizedMessages
    }

    /// The user's latest message. It changes only when the user sends or
    /// retries a message, which is when the transcript jumps to the bottom.
    var latestPromptID: UUID? { messages.last { $0.role == .user }?.id }

    /// Duration and tokens of each agent turn, keyed by the index of its last message.
    var turnStats: [Int: TurnStats] { TurnStats.turns(in: messages) }
    var canSend: Bool { !isRunning && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// A run can be retried when the last one failed, was stopped, or never
    /// answered (e.g. the app quit during the run).
    var canRetry: Bool {
        guard !isRunning, let last = messages.last else { return false }
        switch last.role {
        case .error, .user: return true
        case .assistant: return last.state == .cancelled || last.state == .failed
        case .summary: return false
        }
    }

    /// A spoken message, with an id so the same text can be announced twice.
    struct Announcement: Equatable {
        let id = UUID()
        let text: String
    }

    private let projectRoot: URL
    private let agentService: any AgentService
    private let currentModel: @MainActor () -> AIModel.ID?
    private let runOptions: @MainActor () -> AgentRunOptions
    private let addCommandRule: @MainActor (String) async -> Void
    /// Command prefixes the user allowed for the project during this session,
    /// honored at once, before the next run reads the saved project rules.
    private var commandPrefixesAllowed: [String] = []
    private let persist: @Sendable (UUID, [AgentMessage]) async -> Void
    private let onAttention: @MainActor (AgentAttention) -> Void
    private let now: @Sendable () -> Date
    private var runTask: Task<Void, Never>?
    private var approvalContinuation: CheckedContinuation<ToolApprovalDecision, Never>?

    /// - Parameters:
    ///   - currentModel: read at send time so a model change applies to the next run.
    ///   - runOptions: per-project and per-model settings, also read at send time.
    ///   - addCommandRule: saves a command prefix the user always allows in the project.
    ///   - persist: called with the full transcript after each run ends.
    ///   - onAttention: called when a run ends or waits for an approval, to
    ///     notify the user; not for a run they stopped.
    init(
        sessionID: UUID,
        projectID: UUID? = nil,
        projectRoot: URL,
        messages: [AgentMessage],
        agentService: any AgentService,
        currentModel: @escaping @MainActor () -> AIModel.ID?,
        runOptions: @escaping @MainActor () -> AgentRunOptions = { AgentRunOptions() },
        addCommandRule: @escaping @MainActor (String) async -> Void = { _ in },
        persist: @escaping @Sendable (UUID, [AgentMessage]) async -> Void,
        onAttention: @escaping @MainActor (AgentAttention) -> Void = { _ in },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sessionID = sessionID
        self.projectID = projectID
        self.projectRoot = projectRoot
        self.messages = messages
        self.agentService = agentService
        self.currentModel = currentModel
        self.runOptions = runOptions
        self.addCommandRule = addCommandRule
        self.persist = persist
        self.onAttention = onAttention
        self.now = now
    }

    /// Sends the draft as a new user message and starts a run.
    /// Does nothing if the draft is blank or a run is already in progress.
    func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isRunning else { return }
        draft = ""
        start(prompt: prompt)
    }

    /// Runs the last prompt again, replacing what its failed or stopped run
    /// produced. Keeps the draft the user may be typing.
    func retry() {
        guard canRetry, let index = messages.lastIndex(where: { $0.role == .user }) else { return }
        let prompt = messages[index].text
        messages.removeSubrange(index...)
        start(prompt: prompt)
    }

    private func start(prompt: String) {
        let request = AgentRunRequest(
            sessionID: sessionID,
            projectRoot: projectRoot,
            prompt: prompt,
            history: messages,
            model: currentModel(),
            options: runOptions()
        )
        messages.append(AgentMessage(role: .user, text: prompt, createdAt: now()))
        runState = .running
        announcement = nil
        compactionError = nil
        let saved = messages
        runTask = Task { [weak self] in
            // Saved before the run so a crash or quit never loses the prompt;
            // it can be retried from the transcript.
            await self?.persist(saved)
            await self?.consume(request)
        }
    }

    /// Summarizes the whole session now, so the next run starts from the
    /// summary alone: the messages stay visible but are no longer sent.
    func compact() {
        guard canCompact else { return }
        let request = AgentCompactRequest(sessionID: sessionID, projectRoot: projectRoot, history: messages,
                                          model: currentModel(), options: runOptions())
        runState = .compacting
        announcement = nil
        compactionError = nil
        runTask = Task { [weak self] in
            await self?.consumeCompaction(request)
        }
    }

    private func persist(_ transcript: [AgentMessage]) async {
        await persist(sessionID, transcript)
    }

    /// Stops the current run. Propagates cancellation to the model stream,
    /// running tools and any pending approval (answered with `.deny`).
    func cancel() {
        runTask?.cancel()
    }

    // MARK: Approvals

    func decide(_ request: ToolApprovalRequest) async -> ToolApprovalDecision {
        if toolsAllowedForSession.contains(request.toolName) { return .allowOnce }
        if let command = request.command, CommandRules(allowedPrefixes: commandPrefixesAllowed).allows(command: command) {
            return .allowOnce
        }
        guard !Task.isCancelled else { return .deny }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Only one call runs at a time, so a previous request cannot still be pending.
                approvalContinuation?.resume(returning: .deny)
                approvalContinuation = continuation
                pendingApproval = request
                announcement = Announcement(text: "Approval needed: \(request.summary)")
                onAttention(.approvalNeeded(summary: request.summary))
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.resolveApproval(.deny) }
        }
    }

    /// Answers the pending approval request, if any.
    func resolveApproval(_ decision: ToolApprovalDecision) {
        guard let continuation = approvalContinuation, let request = pendingApproval else { return }
        switch decision {
        case .allowForSession:
            toolsAllowedForSession.insert(request.toolName)
        case .allowCommandInProject(let prefix):
            commandPrefixesAllowed.append(prefix)
            Task { await addCommandRule(prefix) }
        case .allowOnce, .deny:
            break
        }
        approvalContinuation = nil
        pendingApproval = nil
        continuation.resume(returning: decision)
    }

    /// Suspends until the current run, if any, has fully ended.
    func waitUntilIdle() async {
        await runTask?.value
    }

    private func consumeCompaction(_ request: AgentCompactRequest) async {
        var spoken = "The session was compacted."
        do {
            for try await event in agentService.compact(request) {
                if case .contextUsageUpdated(let usage) = event { contextUsage = usage }
                TranscriptReducer.apply(event, to: &messages, now: now())
            }
            if Task.isCancelled {
                TranscriptReducer.cancel(&messages, now: now())
                spoken = "Compacting was stopped."
            }
        } catch is CancellationError {
            TranscriptReducer.cancel(&messages, now: now())
            spoken = "Compacting was stopped."
        } catch {
            // Removes the unfinished summary; the conversation is unchanged.
            TranscriptReducer.cancel(&messages, now: now())
            let presented = UserFacingError(error, title: "Could not compact the session", category: .agent)
            compactionError = presented
            spoken = "Could not compact the session: \(presented.message)"
        }
        announcement = Announcement(text: spoken)
        runState = .idle
        runTask = nil
        await persist(sessionID, messages)
    }

    private func consume(_ request: AgentRunRequest) async {
        var spoken = "The agent finished."
        var attention: AgentAttention?
        do {
            var outcome: AgentRunOutcome?
            for try await event in agentService.run(request, approver: self) {
                switch event {
                case .contextUsageUpdated(let usage): contextUsage = usage
                case .instructionsLoaded(let sources): instructionSources = sources
                case .finished(let finished): outcome = finished
                default: break
                }
                TranscriptReducer.apply(event, to: &messages, now: now())
            }
            // A cancelled consumer ends iteration without throwing.
            if Task.isCancelled {
                TranscriptReducer.cancel(&messages, now: now())
                spoken = "The agent was stopped."
            } else if outcome == .reachedIterationLimit {
                spoken = "The agent paused after its step limit."
                attention = .pausedAtStepLimit
            } else {
                attention = .answered(preview: messages.last { $0.role == .assistant }?.text ?? "")
            }
        } catch is CancellationError {
            TranscriptReducer.cancel(&messages, now: now())
            spoken = "The agent was stopped."
        } catch {
            let presented = UserFacingError(error, title: "The agent run failed", category: .agent)
            TranscriptReducer.fail(&messages, error: presented, now: now())
            spoken = "The agent run failed: \(presented.message)"
            attention = .failed(message: presented.message)
        }
        announcement = Announcement(text: spoken)
        if let attention { onAttention(attention) }
        // A run cannot end while waiting for the user, but never leave a request dangling.
        resolveApproval(.deny)
        runState = .idle
        runTask = nil
        await persist(sessionID, messages)
    }
}
