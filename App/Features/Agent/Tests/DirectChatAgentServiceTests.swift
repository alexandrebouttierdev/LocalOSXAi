import Foundation
import Testing
@testable import LocalOSXAi

@Suite("DirectChatAgentService", .timeLimit(.minutes(1)))
struct DirectChatAgentServiceTests {
    private struct StubResolver: ModelResolving {
        let resolved: ResolvedModel?
        func resolve(_ id: AIModel.ID) async -> ResolvedModel? { resolved }
    }

    private let model = Fixtures.model("gemma4:26b", provider: "fake", advertised: 262_144)

    private func service(_ provider: FakeLLMProvider?, model: AIModel? = nil) -> DirectChatAgentService {
        let model = model ?? self.model
        return DirectChatAgentService(resolver: StubResolver(resolved: provider.map { ResolvedModel(model: model, provider: $0) }))
    }

    private func request(prompt: String = "Explain this project", history: [AgentMessage] = [],
                         model: AIModel.ID? = nil) -> AgentRunRequest {
        AgentRunRequest(sessionID: UUID(), projectRoot: URL(fileURLWithPath: "/tmp/Demo"), prompt: prompt, history: history,
                        model: model ?? self.model.id)
    }

    @Test("streams reasoning and text, then completes")
    func streamsAnswer() async throws {
        let provider = FakeLLMProvider(turns: [.events([.reasoningDelta("Hmm"), .textDelta("Hello"), .finished(.stop)])])
        let result = await collect(service(provider).run(request()))

        #expect(result.error == nil)
        guard case .contextUsageUpdated(let usage) = result.elements.first else {
            Issue.record("Expected context usage first")
            return
        }
        #expect(usage.budgetTokens == ContextWindow.fallbackTokens)
        #expect(Array(result.elements.dropFirst(2)) == [.reasoningDelta("Hmm"), .textDelta("Hello"), .finished(.completed)])
    }

    @Test("the request contains the system prompt, history, prompt and effective context, and no tools")
    func requestContents() async throws {
        let provider = FakeLLMProvider(turns: [.response("ok")])
        let history = [
            AgentMessage(role: .user, text: "First", createdAt: Date()),
            AgentMessage(role: .assistant, text: "Answer", createdAt: Date()),
            AgentMessage(role: .assistant, text: "Broken", state: .failed, createdAt: Date()),
            AgentMessage(role: .error, text: "Server down", createdAt: Date())
        ]
        _ = await collect(service(provider).run(request(prompt: "Second", history: history)))

        let sent = try #require(provider.requests.first)
        #expect(sent.model == "gemma4:26b")
        #expect(sent.tools.isEmpty)
        #expect(sent.options.contextLength == ContextWindow.fallbackTokens)
        #expect(sent.messages.map(\.role) == [.system, .user, .assistant, .user])
        #expect(sent.messages.map(\.content).suffix(3) == ["First", "Answer", "Second"])
        #expect(sent.messages[0].content.contains("Demo"))
    }

    @Test("reported usage replaces the estimate")
    func usageUpdatesContext() async {
        let provider = FakeLLMProvider(turns: [.events([.textDelta("x"), .usage(TokenUsage(promptTokens: 900, completionTokens: 100)),
                                                        .finished(.stop)])])
        let result = await collect(service(provider).run(request()))
        #expect(result.elements.contains(.contextUsageUpdated(ContextUsage(usedTokens: 1_000, budgetTokens: 8_192))))
    }

    @Test("no selected model fails with a clear error")
    func noModel() async {
        let result = await collect(service(FakeLLMProvider()).run(AgentRunRequest(
            sessionID: UUID(), projectRoot: URL(fileURLWithPath: "/tmp"), prompt: "x", history: [], model: nil
        )))
        #expect(result.error as? AgentError == .noModelSelected)
    }

    @Test("a model that is no longer available fails with a clear error")
    func unavailableModel() async {
        let result = await collect(service(nil).run(request()))
        #expect(result.error as? AgentError == .modelUnavailable(name: "gemma4:26b"))
    }

    @Test("provider failures propagate unchanged")
    func providerFailure() async {
        let provider = FakeLLMProvider(turns: [.failureAfter(["Par"], .unreachable(endpoint: "http://localhost:11434"))])
        let result = await collect(service(provider).run(request()))
        #expect(result.elements.contains(.textDelta("Par")))
        #expect(!result.elements.contains(.finished(.completed)))
        #expect(result.error as? ProviderError == .unreachable(endpoint: "http://localhost:11434"))
    }

    @Test("a prompt larger than the context fails before calling the model")
    func contextOverflow() async {
        let tiny = AIModel(provider: "fake", name: "tiny", displayName: "tiny",
                           contextWindow: ContextWindow(advertisedTokens: 2_048), capabilities: [.streaming])
        let provider = FakeLLMProvider()
        let result = await collect(service(provider, model: tiny).run(request(prompt: String(repeating: "word ", count: 2_000))))

        #expect(result.error is AgentError)
        #expect(provider.requests.isEmpty)
    }

    @Test("cancelling the run cancels the model stream")
    func cancellation() async throws {
        let provider = FakeLLMProvider(turns: [.hang])
        let consumer = Task { await collect(service(provider).run(request())) }
        for _ in 0..<200 where provider.requests.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        consumer.cancel()
        _ = await consumer.value
        for _ in 0..<200 where provider.cancelledStreams == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(provider.cancelledStreams == 1)
    }
}

@Suite("ConversationWindow")
struct ConversationWindowTests {
    private func history(_ count: Int) -> [LLMMessage] {
        (0..<count).map { $0.isMultiple(of: 2) ? .user("question \($0) " + String(repeating: "x", count: 400))
                                               : .assistant("answer \($0) " + String(repeating: "y", count: 400)) }
    }

    @Test("everything is kept when it fits")
    func fitsEverything() throws {
        let result = try ConversationWindow.fit(system: "S", history: history(4), prompt: "P", budget: 10_000)
        #expect(result.messages.count == 6)
        #expect(result.droppedMessages == 0)
        #expect(result.messages.first?.role == .system)
        #expect(result.messages.last?.content == "P")
    }

    @Test("the oldest turns are dropped first, and history never starts with an answer")
    func dropsOldest() throws {
        let result = try ConversationWindow.fit(system: "S", history: history(6), prompt: "P", budget: 350)
        #expect(result.droppedMessages > 0)
        #expect(result.estimatedTokens <= 350)
        #expect(result.messages[1].role != .assistant)
        #expect(result.messages.dropFirst().dropLast().last?.content.hasPrefix("answer 5") == true)
    }

    @Test("an oversized prompt is a context overflow")
    func overflow() {
        #expect {
            try ConversationWindow.fit(system: "S", history: [], prompt: String(repeating: "z", count: 4_000), budget: 100)
        } throws: { error in
            guard case AgentError.contextOverflow(_, let budget) = error else { return false }
            return budget == 100
        }
    }

    @Test("a quarter of the context, at least 1K, is reserved for the answer")
    func promptBudget() {
        #expect(ConversationWindow.promptBudget(contextTokens: 8_192) == 6_144)
        #expect(ConversationWindow.promptBudget(contextTokens: 2_048) == 1_024)
        #expect(ConversationWindow.promptBudget(contextTokens: 512) == 0)
    }
}
