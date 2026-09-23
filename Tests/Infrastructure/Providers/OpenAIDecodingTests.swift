import Foundation
import Testing
@testable import LocalOSXAi

@Suite("OpenAI-compatible stream decoding")
struct OpenAIStreamDecoderTests {
    private func decode(_ stream: String) throws -> [LLMEvent] {
        var decoder = OpenAIStreamDecoder(makeID: { "generated" })
        var events = try stream.streamLines.flatMap { try decoder.decode(line: $0) }
        events += try decoder.finish()
        return events
    }

    @Test("text, reasoning and trailing usage are decoded in order")
    func textStream() throws {
        #expect(try decode(OpenAIFixtures.textStream) == [
            .reasoningDelta("Thinking."), .textDelta("Hi"), .textDelta(" there"),
            .usage(TokenUsage(promptTokens: 12, completionTokens: 3)),
            .finished(.stop)
        ])
    }

    @Test("fragmented tool calls are assembled and emitted once, in index order")
    func fragmentedToolCalls() throws {
        #expect(try decode(OpenAIFixtures.fragmentedToolCalls) == [
            .toolCall(LLMToolCall(id: "call_a", name: "read_file", rawArguments: #"{"path":"a.swift"}"#)),
            .toolCall(LLMToolCall(id: "call_b", name: "list_directory", rawArguments: #"{"path":"."}"#)),
            .finished(.toolCalls)
        ])
    }

    @Test("tool calls without an id get one")
    func missingID() throws {
        let stream = """
            data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"x","arguments":"{}"}}]},"finish_reason":"tool_calls"}]}
            data: [DONE]
            """
        #expect(try decode(stream).first == .toolCall(LLMToolCall(id: "generated", name: "x", rawArguments: "{}")))
    }

    @Test("the alternative reasoning field is supported")
    func reasoningField() throws {
        var decoder = OpenAIStreamDecoder()
        #expect(try decoder.decode(line: #"data: {"choices":[{"delta":{"reasoning":"Hmm"}}]}"#) == [.reasoningDelta("Hmm")])
    }

    @Test("a stream closed without [DONE] after a finish reason is complete")
    func closedWithoutDone() throws {
        let stream = #"data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"length"}]}"#
        #expect(try decode(stream) == [.textDelta("ok"), .finished(.length)])
    }

    @Test("a stream closed before any finish reason is an error")
    func truncated() {
        #expect { try decode(#"data: {"choices":[{"delta":{"content":"par"}}]}"#) } throws: { error in
            guard case ProviderError.invalidResponse = error else { return false }
            return true
        }
    }

    @Test("error payloads are classified")
    func errorPayload() {
        var decoder = OpenAIStreamDecoder()
        #expect(throws: ProviderError.httpStatus(code: 500, message: "Model crashed")) {
            try decoder.decode(line: #"data: {"error":{"message":"Model crashed"}}"#)
        }
    }

    @Test("comments, other fields and blank lines are ignored; bad JSON fails")
    func ignoredAndMalformed() throws {
        var decoder = OpenAIStreamDecoder()
        #expect(try decoder.decode(line: ": ping").isEmpty)
        #expect(try decoder.decode(line: "event: message").isEmpty)
        #expect(try decoder.decode(line: "").isEmpty)
        #expect { try decoder.decode(line: "data: {oops") } throws: { error in
            guard case ProviderError.invalidResponse = error else { return false }
            return true
        }
    }

    @Test("nothing is emitted after [DONE]")
    func afterDone() throws {
        var decoder = OpenAIStreamDecoder()
        _ = try decoder.decode(line: "data: [DONE]")
        #expect(try decoder.decode(line: #"data: {"choices":[{"delta":{"content":"late"}}]}"#).isEmpty)
        #expect(try decoder.finish().isEmpty)
    }
}

@Suite("OpenAI-compatible request encoding")
struct OpenAIWireTests {
    @Test("the chat body follows the OpenAI format")
    func chatBody() throws {
        let tool = ToolDefinition(name: "x", description: "d", parameters: .empty)
        let request = LLMRequest(
            model: "qwen3-8b",
            messages: [
                .user("Go"),
                .assistant("", toolCalls: [LLMToolCall(id: "c1", name: "x", rawArguments: #"{"a":1}"#)]),
                .tool("done", callID: "c1", toolName: "x")
            ],
            tools: [tool],
            options: GenerationOptions(temperature: 0.5, contextLength: 99_999, maxOutputTokens: 100, reasoning: .medium)
        )
        let body = try #require(OpenAIWire.chatBody(for: request).objectValue)

        #expect(body["stream"] == true)
        #expect(body["stream_options"] == ["include_usage": true])
        #expect(body["temperature"] == 0.5)
        #expect(body["max_tokens"] == 100)
        #expect(body["reasoning_effort"] == "medium")
        #expect(body["tools"] == [tool.functionToolJSON])
        // The context length is fixed at load time and cannot be requested.
        #expect(!body.keys.contains { $0.contains("ctx") || $0.contains("context") })

        let messages = try #require(body["messages"]?.arrayValue)
        #expect(messages[1].objectValue?["tool_calls"] == [
            ["id": "c1", "type": "function", "function": ["name": "x", "arguments": #"{"a":1}"#]]
        ])
        #expect(messages[2] == ["role": "tool", "content": "done", "tool_call_id": "c1"])
    }

    @Test("reasoning off and empty tools are omitted")
    func omissions() {
        var request = LLMRequest(model: "m", messages: [.user("x")])
        request.options.reasoning = .off
        let body = OpenAIWire.chatBody(for: request).objectValue
        #expect(body?["reasoning_effort"] == nil)
        #expect(body?["tools"] == nil)
    }
}

@Suite("Provider HTTP helpers")
struct ProviderHTTPTests {
    @Test("server messages are extracted from both error formats")
    func errorMessages() {
        #expect(ProviderHTTP.errorMessage(in: Data(#"{"error":"model 'x' not found"}"#.utf8)) == "model 'x' not found")
        #expect(ProviderHTTP.errorMessage(in: Data(#"{"error":{"message":"boom"}}"#.utf8)) == "boom")
        #expect(ProviderHTTP.errorMessage(in: Data("Bad Gateway".utf8)) == "Bad Gateway")
        #expect(ProviderHTTP.errorMessage(in: Data()) == nil)
    }

    @Test("statuses and messages are classified into actionable errors")
    func classification() {
        #expect(ProviderHTTP.classify(status: 400, message: "registry.ollama.ai/x does not support tools")
                == .unsupportedCapability("tool calling"))
        #expect(ProviderHTTP.classify(status: 404, message: nil) == .modelNotFound("unknown model"))
        #expect(ProviderHTTP.classify(status: 500, message: "model 'y' not found") == .modelNotFound("model 'y' not found"))
        #expect(ProviderHTTP.classify(status: 503, message: "busy") == .httpStatus(code: 503, message: "busy"))
    }

    @Test("transport errors map to provider errors and cancellation")
    func translation() throws {
        let request = URLRequest(url: try #require(URL(string: "http://localhost:11434/api/chat")))
        #expect(ProviderHTTP.translate(URLError(.cannotConnectToHost), request: request) as? ProviderError
                == .unreachable(endpoint: "http://localhost:11434"))
        #expect(ProviderHTTP.translate(URLError(.timedOut), request: request) as? ProviderError == .timedOut)
        #expect(ProviderHTTP.translate(URLError(.cancelled), request: request) is CancellationError)
        #expect(ProviderHTTP.translate(ProviderError.timedOut, request: request) as? ProviderError == .timedOut)
    }
}
