import Foundation
import Testing
@testable import LocalOSXAi

@Suite("Simulated services")
struct SimulatedServicesTests {
    private let request = AgentRunRequest(
        sessionID: UUID(), projectRoot: URL(fileURLWithPath: "/tmp/Demo"), prompt: "Explain the project",
        history: [], model: nil
    )

    @Test("simulated agent emits a complete, well-formed run")
    func completeRun() async {
        let result = await collect(SimulatedAgentService(chunkDelay: .zero).run(request, approver: StubApprover()))
        #expect(result.error == nil)
        #expect(result.elements.last == .finished(.completed))

        let startedIDs = result.elements.compactMap { event -> String? in
            if case .toolCallStarted(let record) = event { return record.id }
            return nil
        }
        let finishedIDs = result.elements.compactMap { event -> String? in
            if case .toolCallFinished(let id, _, _, _) = event { return id }
            return nil
        }
        #expect(!startedIDs.isEmpty)
        #expect(startedIDs == finishedIDs)
    }

    @Test("simulated agent reports context usage first")
    func contextUsageFirst() async {
        let result = await collect(SimulatedAgentService(chunkDelay: .zero, contextBudget: 1_000).run(request, approver: StubApprover()))
        guard case .contextUsageUpdated(let usage) = result.elements.first else {
            Issue.record("Expected context usage first")
            return
        }
        #expect(usage.budgetTokens == 1_000)
        #expect(usage.usedTokens > 0)
    }

    @Test("simulated agent stops when cancelled", .timeLimit(.minutes(1)))
    func cancellation() async throws {
        let consumer = Task { await collect(SimulatedAgentService(chunkDelay: .milliseconds(50)).run(request, approver: StubApprover())) }
        try await Task.sleep(for: .milliseconds(20))
        consumer.cancel()
        let result = await consumer.value
        #expect(!result.elements.contains(.finished(.completed)))
    }

    @Test("simulated provider lists one tool-capable model")
    func simulatedProvider() async throws {
        let models = try await SimulatedLLMProvider().listModels()
        #expect(models.count == 1)
        #expect(models.first?.supportsTools == true)
    }
}
