import Foundation

/// Ollama's native API payloads (`/api/tags`, `/api/ps`, `/api/show`, `/api/chat`).
///
/// Only the fields the app uses are decoded; everything is optional because
/// fields appeared across Ollama versions (e.g. `capabilities` in `/api/tags`
/// since 0.12). Reference: docs/ai/providers.md.
enum OllamaWire {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    struct TagsResponse: Decodable {
        struct Model: Decodable {
            let name: String
            let details: ModelDetails?
            let capabilities: [String]?
        }
        let models: [Model]
    }

    struct ModelDetails: Decodable {
        let contextLength: Int?
    }

    struct RunningResponse: Decodable {
        struct Model: Decodable {
            let name: String
            let contextLength: Int?
        }
        let models: [Model]
    }

    struct ShowResponse: Decodable {
        let capabilities: [String]?
        let modelInfo: [String: JSONValue]?

        /// `model_info` keys are prefixed by architecture (`gemma4.context_length`).
        var contextLength: Int? {
            modelInfo?.first { $0.key.hasSuffix(".context_length") }?.value.numberValue.map { Int($0) }
        }
    }

    struct ChatChunk: Decodable {
        struct Message: Decodable {
            let content: String?
            let thinking: String?
            let toolCalls: [ToolCall]?
        }
        struct ToolCall: Decodable {
            let id: String?
            let function: ToolFunction
        }
        let message: Message?
        let done: Bool?
        let doneReason: String?
        let promptEvalCount: Int?
        let evalCount: Int?
        let error: String?
    }

    struct ToolFunction: Decodable {
        let name: String
        let arguments: JSONValue?
    }

    /// Maps Ollama capability names to abstract capabilities.
    /// Returns `nil` for models that cannot chat (embedding models).
    static func capabilities(from names: [String]) -> ModelCapabilities? {
        guard names.contains("completion") else { return nil }
        var capabilities: ModelCapabilities = [.streaming]
        if names.contains("tools") { capabilities.insert(.tools) }
        if names.contains("vision") { capabilities.insert(.vision) }
        if names.contains("thinking") { capabilities.insert(.reasoning) }
        return capabilities
    }
}

// MARK: - Request encoding

extension OllamaWire {
    /// Builds the `/api/chat` body.
    ///
    /// Ollama expects tool-call arguments as a JSON *object* and matches tool
    /// results by `tool_name`, unlike the OpenAI format.
    static func chatBody(for request: LLMRequest) -> JSONValue {
        var body: [String: JSONValue] = [
            "model": .string(request.model),
            "stream": true,
            "messages": .array(request.messages.map(message))
        ]
        if !request.tools.isEmpty {
            body["tools"] = .array(request.tools.map(\.functionToolJSON))
        }
        var options: [String: JSONValue] = [:]
        if let contextLength = request.options.contextLength { options["num_ctx"] = .number(Double(contextLength)) }
        if let temperature = request.options.temperature { options["temperature"] = .number(temperature) }
        if let maxOutput = request.options.maxOutputTokens { options["num_predict"] = .number(Double(maxOutput)) }
        if !options.isEmpty { body["options"] = .object(options) }
        if let reasoning = request.options.reasoning {
            body["think"] = .bool(reasoning != .off)
        }
        return .object(body)
    }

    private static func message(_ message: LLMMessage) -> JSONValue {
        var encoded: [String: JSONValue] = [
            "role": .string(message.role.rawValue),
            "content": .string(message.content)
        ]
        if !message.toolCalls.isEmpty {
            encoded["tool_calls"] = .array(message.toolCalls.map { call in
                ["function": ["name": .string(call.name), "arguments": argumentsObject(call.rawArguments)]]
            })
        }
        if let toolName = message.toolName {
            encoded["tool_name"] = .string(toolName)
        }
        return .object(encoded)
    }

    /// Arguments that were malformed when the model produced them are sent
    /// back as an empty object: the tool result already explains the error.
    private static func argumentsObject(_ raw: String) -> JSONValue {
        guard let parsed = try? JSONValue.parse(raw), parsed.objectValue != nil else { return [:] }
        return parsed
    }
}
