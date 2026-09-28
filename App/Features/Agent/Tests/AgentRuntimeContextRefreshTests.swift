import Foundation
import Testing
@testable import LocalOSXAi

/// A run that starts on the fallback context re-reads the model once its runtime loaded it.
@Suite("AgentRuntime context refresh", .timeLimit(.minutes(1)))
struct AgentRuntimeContextRefreshTests {
    /// As LM Studio lists a model it unloaded, then the same model loaded on demand.
    private var unloaded: AIModel {
        var model = Fixtures.toolModel
        model.contextWindow.advertisedTokens = 262_144
        return model
    }
    private var loaded: AIModel {
        var model = unloaded
        model.contextWindow.loadedTokens = 80_128
        return model
    }

    private func run(_ resolver: SequenceResolver) async throws -> [AgentEvent] {
        let runtime = AgentRuntime(resolver: resolver, tools: try ToolRegistry([EchoTool()]),
                                   instructionsLoader: StubInstructionsLoader())
        let result = await collect(runtime.run(Fixtures.runRequest(), approver: StubApprover()))
        #expect(result.error == nil)
        return result.elements
    }

    private func budgets(_ events: [AgentEvent]) -> [Int] {
        events.compactMap { if case .contextUsageUpdated(let usage) = $0 { usage.budgetTokens } else { nil } }
    }

    @Test("after the first response, the loaded size replaces the fallback for the rest of the run")
    func fallbackIsReplacedByLoadedSize() async throws {
        let provider = FakeLLMProvider(turns: [.toolCalls([Fixtures.call("echo", #"{"text":"a"}"#)]), .response("done")])
        let resolver = SequenceResolver(models: [unloaded, loaded], provider: provider)

        let events = try await run(resolver)

        #expect(provider.requests.map(\.options.contextLength) == [8_192, 80_128])
        #expect(provider.requests.map(\.options.maxOutputTokens) == [nil, RunContext.outputReserve(contextTokens: 80_128)])
        #expect(budgets(events).first == 8_192)
        #expect(budgets(events).last == 80_128)
        #expect(resolver.calls.value == 2)
    }

    @Test("the model is re-read only once per run")
    func refreshedOnce() async throws {
        let provider = FakeLLMProvider(turns: [
            .toolCalls([Fixtures.call("echo", #"{"text":"a"}"#)]), .toolCalls([Fixtures.call("echo", #"{"text":"b"}"#)]),
            .response("done")
        ])
        let resolver = SequenceResolver(models: [unloaded], provider: provider)

        _ = try await run(resolver)

        #expect(provider.requests.count == 3)
        #expect(resolver.calls.value == 2)
    }

    @Test("a known context is not re-read")
    func knownContextNotRefreshed() async throws {
        let provider = FakeLLMProvider(turns: [.toolCalls([Fixtures.call("echo", #"{"text":"a"}"#)]), .response("done")])
        let resolver = SequenceResolver(models: [loaded], provider: provider)

        _ = try await run(resolver)

        #expect(resolver.calls.value == 1)
    }

    @Test("a model that disappears when re-read keeps the run going on its first description")
    func unavailableOnRefreshKeepsRunning() async throws {
        let provider = FakeLLMProvider(turns: [.toolCalls([Fixtures.call("echo", #"{"text":"a"}"#)]), .response("done")])
        let resolver = SequenceResolver(models: [unloaded, nil], provider: provider)

        _ = try await run(resolver)

        #expect(provider.requests.map(\.options.contextLength) == [8_192, 8_192])
    }
}
