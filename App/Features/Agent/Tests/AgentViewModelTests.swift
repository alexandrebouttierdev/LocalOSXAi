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
        #expect(viewModel.messages[2].text == ProviderError.unreachable(endpoint: "x").errorDescription)
    }
}
