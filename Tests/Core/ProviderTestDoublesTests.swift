import Foundation
import Testing
@testable import LocalOSXAi

/// Verifies the provider test doubles themselves, so agent tests built on
/// them in Phase 3 can trust every simulated behavior.
@Suite("Provider test doubles")
struct ProviderTestDoublesTests {
    private let request = LLMRequest(model: "m", messages: [.user("hi")])

    @Test("normal response yields text then finishes with stop")
    func normalResponse() async {
        let provider = FakeLLMProvider(turns: [.response("Hello")])
        let result = await collect(provider.stream(request: request))
        #expect(result.elements == [.textDelta("Hello"), .finished(.stop)])
        #expect(result.error == nil)
    }

    @Test("streaming yields chunks in order")
    func streaming() async {
        let provider = FakeLLMProvider(turns: [.streaming(["a", "b", "c"], delay: .milliseconds(1))])
        let result = await collect(provider.stream(request: request))
        #expect(result.elements == [.textDelta("a"), .textDelta("b"), .textDelta("c"), .finished(.stop)])
    }

    @Test("tool calls finish with the toolCalls reason")
    func toolCalls() async {
        let call = LLMToolCall(id: "1", name: "read_file", rawArguments: #"{"path":"a"}"#)
        let provider = FakeLLMProvider(turns: [.toolCalls([call, call])])
        let result = await collect(provider.stream(request: request))
        #expect(result.elements == [.toolCall(call), .toolCall(call), .finished(.toolCalls)])
    }

    @Test("malformed tool calls carry raw, unparsable arguments")
    func malformedToolCall() async throws {
        let provider = FakeLLMProvider(turns: [.malformedToolCall(name: "read_file", rawArguments: "{path: ")])
        let result = await collect(provider.stream(request: request))
        guard case .toolCall(let call) = result.elements.first else {
            Issue.record("Expected a tool call")
            return
        }
        #expect(throws: ToolError.malformedArguments("{path:")) { try ToolArguments.parse(call.rawArguments) }
    }

    @Test("errors terminate the stream by throwing")
    func failure() async {
        let provider = FakeLLMProvider(turns: [.failure(.modelNotFound("m"))])
        let result = await collect(provider.stream(request: request))
        #expect(result.elements.isEmpty)
        #expect(result.error as? ProviderError == .modelNotFound("m"))
    }

    @Test("partial streams deliver content before failing")
    func failureAfterContent() async {
        let provider = FakeLLMProvider(turns: [.failureAfter(["par"], .unreachable(endpoint: "x"))])
        let result = await collect(provider.stream(request: request))
        #expect(result.elements == [.textDelta("par")])
        #expect(result.error as? ProviderError == .unreachable(endpoint: "x"))
    }

    @Test("timeouts surface as ProviderError.timedOut")
    func timeout() async {
        let provider = FakeLLMProvider(turns: [.timeout(after: .milliseconds(5))])
        let result = await collect(provider.stream(request: request))
        #expect(result.error as? ProviderError == .timedOut)
    }

    @Test("cancelling the consumer cancels the producing stream", .timeLimit(.minutes(1)))
    func cancellation() async throws {
        let provider = FakeLLMProvider(turns: [.hang])
        let consumer = Task { await collect(provider.stream(request: request)) }
        try await Task.sleep(for: .milliseconds(20))
        consumer.cancel()
        _ = await consumer.value
        // The producer observes cancellation asynchronously after termination.
        for _ in 0..<100 where provider.cancelledStreams == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(provider.cancelledStreams == 1)
    }

    @Test("turns are consumed in order and requests are recorded")
    func turnsAndRecording() async {
        let provider = FakeLLMProvider(turns: [.response("one"), .response("two")])
        _ = await collect(provider.stream(request: request))
        let second = await collect(provider.stream(request: request))
        let third = await collect(provider.stream(request: request))
        #expect(second.elements.first == .textDelta("two"))
        #expect(third.error is ProviderError)
        #expect(provider.requests.count == 3)
    }

    @Test("mock provider computes events from the request and records it")
    func mockProvider() async {
        let provider = MockLLMProvider { request in [.textDelta(request.model), .finished(.stop)] }
        let result = await collect(provider.stream(request: request))
        #expect(result.elements == [.textDelta("m"), .finished(.stop)])
        #expect(provider.receivedRequests == [request])
    }

    @Test("mock provider propagates handler errors")
    func mockProviderError() async {
        let provider = MockLLMProvider { _ in throw ProviderError.timedOut }
        let result = await collect(provider.stream(request: request))
        #expect(result.error as? ProviderError == .timedOut)
    }
}
