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
    var draft = ""

    var isRunning: Bool { runState == .running }
    var canSend: Bool { !isRunning && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// A run can be retried when the last one failed, was stopped, or never
    /// answered (e.g. the app quit during the run).
    var canRetry: Bool {
        guard !isRunning, let last = messages.last else { return false }
        switch last.role {
        case .error, .user: return true
        case .assistant: return last.state == .cancelled || last.state == .failed
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
    private let includesClaudeInstructions: @MainActor () -> Bool
    private let persist: @Sendable (UUID, [AgentMessage]) async -> Void
    private let now: @Sendable () -> Date
    private var runTask: Task<Void, Never>?
    private var approvalContinuation: CheckedContinuation<ToolApprovalDecision, Never>?

    /// - Parameters:
    ///   - currentModel: read at send time so a model change applies to the next run.
    ///   - includesClaudeInstructions: the project's opt-in, also read at send time.
    ///   - persist: called with the full transcript after each run ends.
    init(
        sessionID: UUID,
        projectID: UUID? = nil,
        projectRoot: URL,
        messages: [AgentMessage],
        agentService: any AgentService,
        currentModel: @escaping @MainActor () -> AIModel.ID?,
        includesClaudeInstructions: @escaping @MainActor () -> Bool = { false },
        persist: @escaping @Sendable (UUID, [AgentMessage]) async -> Void,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sessionID = sessionID
        self.projectID = projectID
        self.projectRoot = projectRoot
        self.messages = messages
        self.agentService = agentService
        self.currentModel = currentModel
        self.includesClaudeInstructions = includesClaudeInstructions
        self.persist = persist
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
            includesClaudeInstructions: includesClaudeInstructions()
        )
        messages.append(AgentMessage(role: .user, text: prompt, createdAt: now()))
        runState = .running
        announcement = nil
        let saved = messages
        runTask = Task { [weak self] in
            // Saved before the run so a crash or quit never loses the prompt;
            // it can be retried from the transcript.
            await self?.persist(saved)
            await self?.consume(request)
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
        guard !Task.isCancelled else { return .deny }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Only one call runs at a time, so a previous request cannot still be pending.
                approvalContinuation?.resume(returning: .deny)
                approvalContinuation = continuation
                pendingApproval = request
                announcement = Announcement(text: "Approval needed: \(request.summary)")
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.resolveApproval(.deny) }
        }
    }

    /// Answers the pending approval request, if any.
    func resolveApproval(_ decision: ToolApprovalDecision) {
        guard let continuation = approvalContinuation, let request = pendingApproval else { return }
        if decision == .allowForSession { toolsAllowedForSession.insert(request.toolName) }
        approvalContinuation = nil
        pendingApproval = nil
        continuation.resume(returning: decision)
    }

    /// Suspends until the current run, if any, has fully ended.
    func waitUntilIdle() async {
        await runTask?.value
    }

    private func consume(_ request: AgentRunRequest) async {
        var spoken = "The agent finished."
        do {
            for try await event in agentService.run(request, approver: self) {
                switch event {
                case .contextUsageUpdated(let usage): contextUsage = usage
                case .instructionsLoaded(let sources): instructionSources = sources
                case .finished(.reachedIterationLimit): spoken = "The agent paused after its step limit."
                default: break
                }
                TranscriptReducer.apply(event, to: &messages, now: now())
            }
            // A cancelled consumer ends iteration without throwing.
            if Task.isCancelled {
                TranscriptReducer.cancel(&messages)
                spoken = "The agent was stopped."
            }
        } catch is CancellationError {
            TranscriptReducer.cancel(&messages)
            spoken = "The agent was stopped."
        } catch {
            let presented = UserFacingError(error, title: "The agent run failed", category: .agent)
            TranscriptReducer.fail(&messages, error: presented, now: now())
            spoken = "The agent run failed: \(presented.message)"
        }
        announcement = Announcement(text: spoken)
        // A run cannot end while waiting for the user, but never leave a request dangling.
        resolveApproval(.deny)
        runState = .idle
        runTask = nil
        await persist(sessionID, messages)
    }
}
