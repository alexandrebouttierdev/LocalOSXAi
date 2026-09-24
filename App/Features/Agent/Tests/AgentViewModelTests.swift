import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("AgentViewModel", .timeLimit(.minutes(1)))
struct AgentViewModelTests {
    private let root = URL(fileURLWithPath: "/tmp/Demo")
    private let model = AIModel.ID(provider: "fake", name: "m")

    private func makeViewModel(
        _ service: StubAgentService,
        messages: [AgentMessage] = [],
        persisted: Recorder<[AgentMessage]> = Recorder()
    ) -> AgentViewModel {
        AgentViewModel(
            sessionID: UUID(),
            projectRoot: root,
            messages: messages,
            agentService: service,
            currentModel: { [model] in model },
            persist: { _, messages in persisted.record(messages) }
        )
    }

    @Test("sending appends the prompt, streams the answer and persists the transcript")
    func sendStreamsAnswer() async throws {
        let service = StubAgentService(.events([
            .contextUsageUpdated(ContextUsage(usedTokens: 10, budgetTokens: 100)),
            .assistantMessageStarted(id: UUID()), .textDelta("Hi"), .finished(.completed)
        ]))
        let persisted = Recorder<[AgentMessage]>()
        let viewModel = makeViewModel(service, persisted: persisted)
        viewModel.draft = "  Hello  "

        viewModel.send()
        #expect(viewModel.isRunning)
        #expect(viewModel.draft.isEmpty)
        await viewModel.waitUntilIdle()

        #expect(!viewModel.isRunning)
        #expect(viewModel.messages.map(\.role) == [.user, .assistant])
        #expect(viewModel.messages[0].text == "Hello")
        #expect(viewModel.messages[1].text == "Hi")
        #expect(viewModel.messages[1].state == .complete)
        #expect(viewModel.contextUsage == ContextUsage(usedTokens: 10, budgetTokens: 100))
        #expect(persisted.values.last == viewModel.messages)
    }

    @Test("the request carries prompt, history, project and current model")
    func requestContents() async throws {
        let earlier = AgentMessage(role: .user, text: "Earlier", createdAt: Date())
        let service = StubAgentService(.events([.finished(.completed)]))
        let viewModel = makeViewModel(service, messages: [earlier])
        viewModel.draft = "Now"

        viewModel.send()
        await viewModel.waitUntilIdle()

        let request = try #require(service.requests.first)
        #expect(request.prompt == "Now")
        #expect(request.history == [earlier])
        #expect(request.projectRoot == root)
        #expect(request.model == model)
    }

    @Test("blank drafts are not sent")
    func blankDraft() {
        let service = StubAgentService(.events([]))
        let viewModel = makeViewModel(service)
        viewModel.draft = " \n "

        #expect(!viewModel.canSend)
        viewModel.send()

        #expect(viewModel.messages.isEmpty)
        #expect(service.requests.isEmpty)
    }

    @Test("a second send while running is ignored")
    func noConcurrentRuns() async {
        let service = StubAgentService(.hangAfter([]))
        let viewModel = makeViewModel(service)
        viewModel.draft = "First"
        viewModel.send()
        viewModel.draft = "Second"

        #expect(!viewModel.canSend)
        viewModel.send()

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.draft == "Second")
        viewModel.cancel()
        await viewModel.waitUntilIdle()
    }

    @Test("cancelling stops the run and propagates cancellation to the service")
    func cancellation() async throws {
        let service = StubAgentService(.hangAfter([.assistantMessageStarted(id: UUID()), .textDelta("Partial")]))
        let viewModel = makeViewModel(service)
        viewModel.draft = "Go"
        viewModel.send()

        // Wait for the partial answer to arrive before cancelling.
        for _ in 0..<200 where viewModel.messages.count < 2 {
            try await Task.sleep(for: .milliseconds(5))
        }
        viewModel.cancel()
        await viewModel.waitUntilIdle()

        #expect(!viewModel.isRunning)
        #expect(viewModel.messages.last?.state == .cancelled)
        #expect(viewModel.messages.last?.text == "Partial")
        for _ in 0..<200 where service.cancellationCount == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(service.cancellationCount == 1)
    }

    @Test("a failing run shows an error entry and returns to idle")
    func failure() async {
        let service = StubAgentService(.failAfter([.assistantMessageStarted(id: UUID())], ProviderError.unreachable(endpoint: "x")))
        let viewModel = makeViewModel(service)
        viewModel.draft = "Go"

        viewModel.send()
        await viewModel.waitUntilIdle()

        #expect(!viewModel.isRunning)
        #expect(viewModel.messages.map(\.role) == [.user, .assistant, .error])
        #expect(viewModel.messages[1].state == .failed)
        let error = ProviderError.unreachable(endpoint: "x")
        #expect(viewModel.messages[2].text
                == [error.errorDescription, error.recoverySuggestion].compactMap { $0 }.joined(separator: "\n"))
        #expect(viewModel.announcement?.text.hasPrefix("The agent run failed") == true)
    }

    @Test("a failed run can be retried: its output is replaced by the new run")
    func retryAfterFailure() async {
        let service = StubAgentService(sequence: [
            .failAfter([.assistantMessageStarted(id: UUID())], ProviderError.timedOut),
            .events([.assistantMessageStarted(id: UUID()), .textDelta("Recovered"), .finished(.completed)])
        ])
        let viewModel = makeViewModel(service, messages: [
            AgentMessage(role: .user, text: "Earlier", createdAt: Date()),
            AgentMessage(role: .assistant, text: "Earlier answer", createdAt: Date())
        ])
        viewModel.draft = "Go"
        viewModel.send()
        await viewModel.waitUntilIdle()
        #expect(viewModel.canRetry)

        viewModel.draft = "typing something else"
        viewModel.retry()
        await viewModel.waitUntilIdle()

        #expect(viewModel.messages.map(\.text) == ["Earlier", "Earlier answer", "Go", "Recovered"])
        #expect(!viewModel.canRetry)
        #expect(viewModel.draft == "typing something else")
        #expect(service.requests.map(\.prompt) == ["Go", "Go"])
        #expect(service.requests[1].history.map(\.text) == ["Earlier", "Earlier answer"])
        #expect(viewModel.announcement?.text == "The agent finished.")
    }

    @Test("retry is offered only when the last run did not complete")
    func retryAvailability() {
        func canRetry(_ messages: [AgentMessage]) -> Bool {
            makeViewModel(StubAgentService(.events([])), messages: messages).canRetry
        }
        let user = AgentMessage(role: .user, text: "Q", createdAt: Date())
        #expect(!canRetry([]))
        #expect(canRetry([user]))
        #expect(!canRetry([user, AgentMessage(role: .assistant, text: "A", createdAt: Date())]))
        #expect(canRetry([user, AgentMessage(role: .assistant, text: "", state: .cancelled, createdAt: Date())]))
        #expect(canRetry([user, AgentMessage(role: .error, text: "Boom", createdAt: Date())]))
    }

    @Test("the prompt is saved before the run starts, so quitting mid-run keeps it")
    func savesPromptFirst() async {
        let persisted = Recorder<[AgentMessage]>()
        let viewModel = makeViewModel(StubAgentService(.hangAfter([])), persisted: persisted)
        viewModel.draft = "Long task"
        viewModel.send()
        for _ in 0..<200 where persisted.values.isEmpty {
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(persisted.values.first?.map(\.text) == ["Long task"])

        viewModel.cancel()
        await viewModel.waitUntilIdle()
        #expect(viewModel.announcement?.text == "The agent was stopped.")
    }

    // MARK: Approvals

    private let approval = ToolApprovalRequest(id: "c1", toolName: "write_file", summary: "Write a.txt (1 lines)",
                                               reason: "This changes files in your project.")

    private func waitForPendingApproval(_ viewModel: AgentViewModel) async throws {
        for _ in 0..<200 where viewModel.pendingApproval == nil {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("an approval request is shown and answered by the user")
    func approvalAnswered() async throws {
        let decisions = Recorder<ToolApprovalDecision>()
        let viewModel = makeViewModel(StubAgentService(.askApproval(approval, decisions: decisions)))
        viewModel.draft = "Go"
        viewModel.send()
        try await waitForPendingApproval(viewModel)

        #expect(viewModel.pendingApproval == approval)
        #expect(viewModel.announcement?.text == "Approval needed: \(approval.summary)")
        viewModel.resolveApproval(.allowOnce)
        await viewModel.waitUntilIdle()

        #expect(decisions.values == [.allowOnce])
        #expect(viewModel.pendingApproval == nil)
    }

    @Test("allowing for the session stops asking for that tool")
    func allowForSession() async throws {
        let decisions = Recorder<ToolApprovalDecision>()
        let viewModel = makeViewModel(StubAgentService(.askApproval(approval, decisions: decisions)))
        viewModel.draft = "First"
        viewModel.send()
        try await waitForPendingApproval(viewModel)
        viewModel.resolveApproval(.allowForSession)
        await viewModel.waitUntilIdle()

        viewModel.draft = "Second"
        viewModel.send()
        await viewModel.waitUntilIdle()

        #expect(decisions.values == [.allowForSession, .allowOnce])
        #expect(viewModel.toolsAllowedForSession == ["write_file"])
    }

    @Test("stopping the run while an approval is pending denies it")
    func cancelDeniesPendingApproval() async throws {
        let decisions = Recorder<ToolApprovalDecision>()
        let viewModel = makeViewModel(StubAgentService(.askApproval(approval, decisions: decisions)))
        viewModel.draft = "Go"
        viewModel.send()
        try await waitForPendingApproval(viewModel)

        viewModel.cancel()
        await viewModel.waitUntilIdle()

        #expect(viewModel.pendingApproval == nil)
        for _ in 0..<200 where decisions.values.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        #expect(decisions.values == [.deny])
    }

    @Test("instruction sources are exposed")
    func instructionSources() async {
        let viewModel = makeViewModel(StubAgentService(.events([.instructionsLoaded(["AGENTS.md"]), .finished(.completed)])))
        viewModel.draft = "Go"
        viewModel.send()
        await viewModel.waitUntilIdle()
        #expect(viewModel.instructionSources == ["AGENTS.md"])
    }
}
