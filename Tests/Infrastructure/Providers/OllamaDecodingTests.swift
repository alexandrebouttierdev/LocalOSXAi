import Foundation
import Testing
@testable import LocalOSXAi

@Suite("Ollama stream decoding")
struct OllamaStreamDecoderTests {
    private func decode(_ stream: String) throws -> [LLMEvent] {
        var decoder = OllamaStreamDecoder(makeID: { "generated" })
        var events = try stream.streamLines.flatMap { try decoder.decode(line: $0) }
        events += try decoder.finish()
        return events
    }

    @Test("a recorded text stream yields deltas, usage and stop")
    func recordedTextStream() throws {
        #expect(try decode(OllamaFixtures.textStream) == [
            .textDelta("Hello"), .textDelta(" to"), .textDelta(" you"), .textDelta("!"),
            .usage(TokenUsage(promptTokens: 20, completionTokens: 5)),
            .finished(.stop)
        ])
    }

    @Test("thinking and tool calls are normalized, with generated ids and serialized arguments")
    func thinkingAndToolCalls() throws {
        #expect(try decode(OllamaFixtures.thinkingToolStream) == [
            .reasoningDelta("I should read it."),
            .toolCall(LLMToolCall(id: "generated", name: "read_file", rawArguments: #"{"path":"README.md"}"#)),
            .usage(TokenUsage(promptTokens: 40, completionTokens: 12)),
            .finished(.toolCalls)
        ])
    }

    @Test("tool call ids sent by newer servers are kept")
    func keepsServerIDs() throws {
        let line = #"{"message":{"content":"","tool_calls":[{"id":"call_7","function":{"name":"x","arguments":{}}}]},"done":false}"#
        var decoder = OllamaStreamDecoder(makeID: { "generated" })
        #expect(try decoder.decode(line: line) == [.toolCall(LLMToolCall(id: "call_7", name: "x", rawArguments: "{}"))])
    }

    @Test("a length stop is reported")
    func lengthStop() throws {
        var decoder = OllamaStreamDecoder()
        #expect(try decoder.decode(line: #"{"message":{"content":""},"done":true,"done_reason":"length"}"#) == [.finished(.length)])
    }

    @Test("error lines are classified")
    func errorLine() {
        var decoder = OllamaStreamDecoder()
        #expect(throws: ProviderError.modelNotFound("model 'nope' not found")) {
            try decoder.decode(line: #"{"error":"model 'nope' not found"}"#)
        }
    }

    @Test("unreadable lines fail clearly and blank lines are ignored")
    func malformedAndBlank() throws {
        var decoder = OllamaStreamDecoder()
        #expect(try decoder.decode(line: "   ").isEmpty)
        #expect { try decoder.decode(line: "{not json") } throws: { error in
            guard case ProviderError.invalidResponse = error else { return false }
            return true
        }
    }

    @Test("a stream that ends before done is an error")
    func truncatedStream() throws {
        var decoder = OllamaStreamDecoder()
        _ = try decoder.decode(line: #"{"message":{"content":"Hel"},"done":false}"#)
        #expect { try decoder.finish() } throws: { error in
            guard case ProviderError.invalidResponse = error else { return false }
            return true
        }
    }
}

@Suite("Ollama request encoding")
struct OllamaWireTests {
    private let tool = ToolDefinition(
        name: "read_file", description: "Read a file",
        parameters: ToolParameterSchema(properties: ["path": .init(.string, "Path")], required: ["path"])
    )

    @Test("the chat body carries messages, options, tools and think")
    func chatBody() throws {
        let request = LLMRequest(
            model: "gemma4:26b",
            messages: [
                .system("Be brief."),
                .user("Read it"),
                .assistant("", toolCalls: [LLMToolCall(id: "c1", name: "read_file", rawArguments: #"{"path":"a"}"#)]),
                .tool("contents", callID: "c1", toolName: "read_file")
            ],
            tools: [tool],
            options: GenerationOptions(temperature: 0.2, contextLength: 16_384, maxOutputTokens: 512, reasoning: .high)
        )
        let body = try #require(OllamaWire.chatBody(for: request).objectValue)

        #expect(body["model"] == "gemma4:26b")
        #expect(body["stream"] == true)
        #expect(body["think"] == true)
        #expect(body["options"] == ["num_ctx": 16_384, "temperature": 0.2, "num_predict": 512])
        #expect(body["tools"] == [tool.functionToolJSON])

        let messages = try #require(body["messages"]?.arrayValue)
        #expect(messages[0] == ["role": "system", "content": "Be brief."])
        #expect(messages[2].objectValue?["tool_calls"] == [["function": ["name": "read_file", "arguments": ["path": "a"]]]])
        #expect(messages[3] == ["role": "tool", "content": "contents", "tool_name": "read_file"])
    }

    @Test("think is omitted by default and false when reasoning is off")
    func thinkFlag() {
        let plain = LLMRequest(model: "m", messages: [.user("x")])
        #expect(OllamaWire.chatBody(for: plain).objectValue?["think"] == nil)
        #expect(OllamaWire.chatBody(for: plain).objectValue?["tools"] == nil)
        var off = plain
        off.options.reasoning = .off
        #expect(OllamaWire.chatBody(for: off).objectValue?["think"] == false)
    }

    @Test("malformed historical arguments are sent as an empty object")
    func malformedHistoricalArguments() throws {
        let request = LLMRequest(model: "m", messages: [
            .assistant("", toolCalls: [LLMToolCall(id: "c", name: "x", rawArguments: "{broken")])
        ])
        let message = try #require(OllamaWire.chatBody(for: request).objectValue?["messages"]?.arrayValue?.first)
        #expect(message.objectValue?["tool_calls"] == [["function": ["name": "x", "arguments": [:]]]])
    }

    @Test("capability names map to abstract capabilities; embedding models are excluded")
    func capabilities() {
        #expect(OllamaWire.capabilities(from: ["completion", "tools", "vision", "thinking"]) == [.streaming, .tools, .vision, .reasoning])
        #expect(OllamaWire.capabilities(from: ["completion"]) == [.streaming])
        #expect(OllamaWire.capabilities(from: ["embedding"]) == nil)
    }
}
