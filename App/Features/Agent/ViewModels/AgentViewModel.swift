import Foundation
import Observation

/// State and actions of the conversation for one session.
///
/// Depends only on `AgentService`, so the same view model drives the real
/// agent, the simulated agent and test stubs. Transcript rules live in
/// `TranscriptReducer`; this type only orchestrates the run lifecycle.
@MainActor
@Observable
final class AgentViewModel {
    enum RunState: Equatable {
        case idle
        case running
    }

    let sessionID: UUID
    private(set) var messages: [AgentMessage]
    private(set) var runState: RunState = .idle
    private(set) var contextUsage: ContextUsage?
    var draft = ""

    var isRunning: Bool { runState == .running }
    var canSend: Bool { !isRunning && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private let projectRoot: URL
    private let agentService: any AgentService
    private let currentModel: @MainActor () -> AIModel.ID?
    private let persist: @Sendable (UUID, [AgentMessage]) async -> Void
    private let now: @Sendable () -> Date
    private var runTask: Task<Void, Never>?

    /// - Parameters:
    ///   - currentModel: read at send time so a model change applies to the next run.
    ///   - persist: called with the full transcript after each run ends.
    init(
        sessionID: UUID,
        projectRoot: URL,
        messages: [AgentMessage],
        agentService: any AgentService,
        currentModel: @escaping @MainActor () -> AIModel.ID?,
        persist: @escaping @Sendable (UUID, [AgentMessage]) async -> Void,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sessionID = sessionID
        self.projectRoot = projectRoot
        self.messages = messages
        self.agentService = agentService
        self.currentModel = currentModel
        self.persist = persist
        self.now = now
    }

    /// Sends the draft as a new user message and starts a run.
    /// Does nothing if the draft is blank or a run is already in progress.
    func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isRunning else { return }

        let request = AgentRunRequest(
            sessionID: sessionID,
            projectRoot: projectRoot,
            prompt: prompt,
            history: messages,
            model: currentModel()
        )
        draft = ""
        messages.append(AgentMessage(role: .user, text: prompt, createdAt: now()))
        runState = .running
        runTask = Task { [weak self] in
            await self?.consume(request)
        }
    }

    /// Stops the current run. Propagates cancellation to the model stream and
    /// running tools through the stream's termination handler.
    func cancel() {
        runTask?.cancel()
    }

    /// Suspends until the current run, if any, has fully ended.
    func waitUntilIdle() async {
        await runTask?.value
    }

    private func consume(_ request: AgentRunRequest) async {
        do {
            for try await event in agentService.run(request) {
                if case .contextUsageUpdated(let usage) = event { contextUsage = usage }
                TranscriptReducer.apply(event, to: &messages, now: now())
            }
            // A cancelled consumer ends iteration without throwing.
            if Task.isCancelled { TranscriptReducer.cancel(&messages) }
        } catch is CancellationError {
            TranscriptReducer.cancel(&messages)
        } catch {
            let presented = UserFacingError(error, title: "The agent run failed", category: .agent)
            TranscriptReducer.fail(&messages, error: presented, now: now())
        }
        runState = .idle
        runTask = nil
        await persist(sessionID, messages)
    }
}
