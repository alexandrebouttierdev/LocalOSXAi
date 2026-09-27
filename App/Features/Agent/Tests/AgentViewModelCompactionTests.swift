import Foundation
import Testing
@testable import LocalOSXAi

/// “Compact session”: the user summarizes the conversation on request.
@MainActor
@Suite("AgentViewModel compaction", .timeLimit(.minutes(1)))
struct AgentViewModelCompactionTests {
    private let model = AIModel.ID(provider: "fake", name: "m")

    private func makeViewModel(
        _ service: StubAgentService,
        messages: [AgentMessage] = [],
        persisted: Recorder<[AgentMessage]> = Recorder()
    ) -> AgentViewModel {
        AgentViewModel(
            sessionID: UUID(),
            projectRoot: URL(fileURLWithPath: "/tmp/Demo"),
            messages: messages,
            agentService: service,
            currentModel: { [model] in model },
            persist: { _, messages in persisted.record(messages) }
        )
    }

    private func exchange() -> [AgentMessage] {
        [AgentMessage(role: .user, text: "Question", createdAt: Date()),
         AgentMessage(role: .assistant, text: "Answer", createdAt: Date())]
    }

    @Test("compacting inserts the summary after the last message, updates usage and persists")
    func compact() async throws {
        let messages = exchange()
        let id = UUID()
        let usage = ContextUsage(usedTokens: 50, budgetTokens: 8_192)
        let service = StubAgentService(.events([]), compaction: .events([
            .historySummaryStarted(id: id, afterMessageID: messages[1].id),
            .historySummaryFinished(id: id, text: "Asked a question."),
            .contextUsageUpdated(usage)
        ]))
        let persisted = Recorder<[AgentMessage]>()
        let viewModel = makeViewModel(service, messages: messages, persisted: persisted)
        #expect(viewModel.canCompact)

        viewModel.compact()
        #expect(viewModel.isCompacting)
        #expect(viewModel.isRunning)
        #expect(!viewModel.canCompact)
        await viewModel.waitUntilIdle()

        #expect(!viewModel.isRunning)
        #expect(viewModel.messages.map(\.role) == [.user, .assistant, .summary])
        #expect(viewModel.messages[2].text == "Asked a question.")
        #expect(viewModel.messages[2].state == .complete)
        #expect(viewModel.contextUsage == usage)
        #expect(persisted.values.last == viewModel.messages)
        #expect(viewModel.announcement?.text == "The session was compacted.")
        let request = try #require(service.compactions.first)
        #expect(request.history == messages)
        #expect(request.model == model)
        #expect(service.requests.isEmpty)
        // Nothing new to summarize until the next exchange.
        #expect(!viewModel.canCompact)
        #expect(!viewModel.canRetry)
    }

    @Test("a failed compaction leaves the conversation as it was and says why")
    func compactFailure() async {
        let messages = exchange()
        let id = UUID()
        let service = StubAgentService(.events([.finished(.completed)]), compaction: .failAfter(
            [.historySummaryStarted(id: id, afterMessageID: messages[1].id)], ProviderError.timedOut
        ))
        let viewModel = makeViewModel(service, messages: messages)

        viewModel.compact()
        await viewModel.waitUntilIdle()

        #expect(viewModel.messages == messages)
        #expect(viewModel.compactionError?.title == "Could not compact the session")
        #expect(viewModel.compactionError?.message == ProviderError.timedOut.errorDescription)
        #expect(!viewModel.canRetry)
        #expect(viewModel.canCompact)

        viewModel.draft = "Go on"
        viewModel.send()
        #expect(viewModel.compactionError == nil)
        await viewModel.waitUntilIdle()
    }

    @Test("stopping a compaction removes the unfinished summary")
    func compactCancelled() async throws {
        let messages = exchange()
        let service = StubAgentService(.events([]), compaction: .hangAfter([
            .historySummaryStarted(id: UUID(), afterMessageID: messages[1].id)
        ]))
        let viewModel = makeViewModel(service, messages: messages)

        viewModel.compact()
        for _ in 0..<200 where viewModel.messages.count < 3 { try await Task.sleep(for: .milliseconds(5)) }
        viewModel.cancel()
        await viewModel.waitUntilIdle()

        #expect(viewModel.messages == messages)
        #expect(viewModel.compactionError == nil)
        #expect(viewModel.announcement?.text == "Compacting was stopped.")
    }

    @Test("compacting needs one exchange since the last summary and no run in progress")
    func compactAvailability() async {
        #expect(!makeViewModel(StubAgentService(.events([]))).canCompact)
        #expect(!makeViewModel(StubAgentService(.events([])), messages: Array(exchange().prefix(1))).canCompact)
        let summarized = exchange() + [AgentMessage(role: .summary, text: "S", createdAt: Date())]
        #expect(!makeViewModel(StubAgentService(.events([])), messages: summarized).canCompact)

        let service = StubAgentService(.hangAfter([]))
        let viewModel = makeViewModel(service, messages: exchange())
        viewModel.draft = "More"
        viewModel.send()
        #expect(!viewModel.canCompact)
        viewModel.compact()
        viewModel.cancel()
        await viewModel.waitUntilIdle()
        #expect(service.compactions.isEmpty)
    }
}
