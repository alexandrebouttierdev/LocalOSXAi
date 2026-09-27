import Foundation
import Testing
@testable import LocalOSXAi

/// The transcript shows the latest page of messages and loads earlier pages on demand.
@MainActor
@Suite("AgentViewModel paging", .timeLimit(.minutes(1)))
struct AgentViewModelPagingTests {
    private let page = AgentViewModel.messagePageSize

    private func exchanges(_ count: Int) -> [AgentMessage] {
        (0..<count).map { index in
            AgentMessage(role: index.isMultiple(of: 2) ? .user : .assistant, text: "\(index)", state: .complete, createdAt: Date())
        }
    }

    private func makeViewModel(messageCount: Int, service: StubAgentService = StubAgentService(.events([]))) -> AgentViewModel {
        makeViewModel(messages: exchanges(messageCount), service: service)
    }

    private func makeViewModel(messages: [AgentMessage], service: StubAgentService) -> AgentViewModel {
        AgentViewModel(sessionID: UUID(), projectRoot: URL(fileURLWithPath: "/tmp/Demo"), messages: messages,
                       agentService: service, currentModel: { AIModel.ID(provider: "fake", name: "m") },
                       persist: { _, _ in })
    }

    @Test("a short session shows every message")
    func shortSessionShowsAll() {
        let viewModel = makeViewModel(messageCount: page - 1)
        #expect(viewModel.firstVisibleIndex == 0)
    }

    @Test("a long session opens on its latest page")
    func longSessionShowsLatestPage() {
        let viewModel = makeViewModel(messageCount: page * 2 + 5)
        #expect(viewModel.firstVisibleIndex == page + 5)
    }

    @Test("earlier pages load one at a time, down to the first message")
    func showEarlierMessages() {
        let viewModel = makeViewModel(messageCount: page * 2 + 5)

        viewModel.showEarlierMessages()
        #expect(viewModel.firstVisibleIndex == 5)

        viewModel.showEarlierMessages()
        #expect(viewModel.firstVisibleIndex == 0)

        viewModel.showEarlierMessages()
        #expect(viewModel.firstVisibleIndex == 0)
    }

    @Test("new messages are always shown, without hiding the earlier ones already shown")
    func newMessagesStayVisible() async {
        let service = StubAgentService(.events([.assistantMessageStarted(id: UUID()), .textDelta("Hi"), .finished(.completed)]))
        let viewModel = makeViewModel(messageCount: page + 10, service: service)
        let first = viewModel.firstVisibleIndex

        viewModel.draft = "Next"
        viewModel.send()
        await viewModel.waitUntilIdle()

        #expect(viewModel.messages.count == page + 12)
        #expect(viewModel.firstVisibleIndex == first)
    }

    @Test("retrying a long failed turn removes its messages but keeps a page visible")
    func retryKeepsAPage() async {
        // A turn of many tool iterations (one assistant message each) that failed.
        let turn = [AgentMessage(role: .user, text: "Do it", state: .complete, createdAt: Date())]
            + (0..<page).map { _ in AgentMessage(role: .assistant, text: "step", state: .complete, createdAt: Date()) }
            + [AgentMessage(role: .error, text: "Failed", state: .complete, createdAt: Date())]
        let viewModel = makeViewModel(messages: exchanges(12) + turn, service: StubAgentService(.events([.finished(.completed)])))
        #expect(viewModel.firstVisibleIndex > 0)

        viewModel.retry()
        await viewModel.waitUntilIdle()

        #expect(viewModel.messages.count == 13)
        #expect(viewModel.firstVisibleIndex == 0)
    }
}
