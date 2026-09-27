import Foundation
import Testing
@testable import LocalOSXAi

/// What `AgentViewModel` reports so the user can be notified.
@MainActor
@Suite("AgentViewModel attention", .timeLimit(.minutes(1)))
struct AgentViewModelAttentionTests {
    private func run(_ service: StubAgentService) async -> [AgentAttention] {
        var reported: [AgentAttention] = []
        let viewModel = AgentViewModel(
            sessionID: UUID(), projectRoot: URL(fileURLWithPath: "/tmp/Demo"), messages: [], agentService: service,
            currentModel: { AIModel.ID(provider: "fake", name: "m") }, persist: { _, _ in },
            onAttention: { reported.append($0) }
        )
        viewModel.draft = "Go"
        viewModel.send()
        await viewModel.waitUntilIdle()
        return reported
    }

    @Test("an answer is reported with its text")
    func answered() async {
        let reported = await run(StubAgentService(.events([
            .assistantMessageStarted(id: UUID()), .textDelta("All done."), .finished(.completed)
        ])))
        #expect(reported == [.answered(preview: "All done.")])
    }

    @Test("a pause at the step limit and a failure are reported")
    func pausedAndFailed() async {
        #expect(await run(StubAgentService(.events([.finished(.reachedIterationLimit)]))) == [.pausedAtStepLimit])
        let failed = await run(StubAgentService(.failAfter([], ProviderError.timedOut)))
        #expect(failed == [.failed(message: ProviderError.timedOut.errorDescription ?? "")])
    }

    @Test("an approval request is reported while the run waits")
    func approval() async {
        let decisions = Recorder<ToolApprovalDecision>()
        let request = ToolApprovalRequest(id: "1", toolName: "run_command", summary: "Run make", reason: "Runs a command",
                                          command: "make")
        var reported: [AgentAttention] = []
        let viewModel = AgentViewModel(
            sessionID: UUID(), projectRoot: URL(fileURLWithPath: "/tmp/Demo"), messages: [],
            agentService: StubAgentService(.askApproval(request, decisions: decisions)),
            currentModel: { nil }, persist: { _, _ in }, onAttention: { reported.append($0) }
        )
        viewModel.draft = "Build"
        viewModel.send()
        for _ in 0..<200 where viewModel.pendingApproval == nil { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(reported == [.approvalNeeded(summary: "Run make")])
        viewModel.resolveApproval(.deny)
        await viewModel.waitUntilIdle()
    }

    @Test("a run the user stopped is not reported")
    func cancelled() async throws {
        var reported: [AgentAttention] = []
        let viewModel = AgentViewModel(
            sessionID: UUID(), projectRoot: URL(fileURLWithPath: "/tmp/Demo"), messages: [],
            agentService: StubAgentService(.hangAfter([.assistantMessageStarted(id: UUID())])),
            currentModel: { nil }, persist: { _, _ in }, onAttention: { reported.append($0) }
        )
        viewModel.draft = "Go"
        viewModel.send()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.cancel()
        await viewModel.waitUntilIdle()
        #expect(reported.isEmpty)
    }
}
