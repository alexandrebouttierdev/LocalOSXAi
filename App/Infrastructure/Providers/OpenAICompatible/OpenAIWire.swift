import Foundation

/// OpenAI-compatible chat payloads, plus LM Studio's native model listing.
enum OpenAIWire {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    struct ModelsResponse: Decodable {
        struct Model: Decodable {
            let id: String
        }
        let data: [Model]
    }

    /// LM Studio `/api/v0/models`: adds type, load state and context sizes.
    struct LMStudioModelsResponse: Decodable {
        struct Model: Decodable {
            let id: String
            let type: String?
            let state: String?
            let maxContextLength: Int?
            let loadedContextLength: Int?
            let capabilities: [String]?
        }
        let data: [Model]
    }

    struct ChatChunk: Decodable {
        struct Choice: Decodable {
            let delta: Delta?
            let finishReason: String?
        }
        struct Usage: Decodable {
            let promptTokens: Int?
            let completionTokens: Int?
        }
        struct ErrorPayload: Decodable {
            let message: String?
        }
        let choices: [Choice]?
        let usage: Usage?
        let error: ErrorPayload?
    }

    struct Delta: Decodable {
        let content: String?
        /// Reasoning text; servers disagree on the field name.
        let reasoningContent: String?
        let reasoning: String?
        let toolCalls: [ToolCallDelta]?
    }

    struct ToolCallDelta: Decodable {
        let index: Int?
        let id: String?
        let function: FunctionDelta?
    }

    struct FunctionDelta: Decodable {
        let name: String?
        let arguments: String?
    }
}

// MARK: - Request encoding

extension OpenAIWire {
    static func chatBody(for request: LLMRequest) -> JSONValue {
        var body: [String: JSONValue] = [
            "model": .string(request.model),
            "stream": true,
            "stream_options": ["include_usage": true],
            "messages": .array(request.messages.map(message))
        ]
        if !request.tools.isEmpty {
            body["tools"] = .array(request.tools.map(\.functionToolJSON))
        }
        if let temperature = request.options.temperature { body["temperature"] = .number(temperature) }
        if let maxOutput = request.options.maxOutputTokens { body["max_tokens"] = .number(Double(maxOutput)) }
        if let reasoning = request.options.reasoning, reasoning != .off {
            body["reasoning_effort"] = .string(reasoning.rawValue)
        }
        // The context length cannot be set through this API: it is fixed when
        // the server loads the model, and reported as `loadedTokens`.
        return .object(body)
    }

    private static func message(_ message: LLMMessage) -> JSONValue {
        var encoded: [String: JSONValue] = [
            "role": .string(message.role.rawValue),
            "content": .string(message.content)
        ]
        if !message.toolCalls.isEmpty {
            encoded["tool_calls"] = .array(message.toolCalls.map { call in
                [
                    "id": .string(call.id),
                    "type": "function",
                    "function": ["name": .string(call.name), "arguments": .string(call.rawArguments)]
                ]
            })
        }
        if let toolCallID = message.toolCallID {
            encoded["tool_call_id"] = .string(toolCallID)
        }
        return .object(encoded)
    }
}
