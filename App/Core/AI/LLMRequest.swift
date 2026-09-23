import Foundation

/// A provider-independent chat completion request.
///
/// Providers translate this value into their wire format. Nothing in it is
/// specific to Ollama, LM Studio or OpenAI; see docs/ai/providers.md.
struct LLMRequest: Sendable, Hashable {
    /// The provider's model identifier (`AIModel.name`).
    var model: String
    var messages: [LLMMessage]
    /// Tools the model may call. Empty means tool calling is disabled.
    var tools: [ToolDefinition]
    var options: GenerationOptions

    init(model: String, messages: [LLMMessage], tools: [ToolDefinition] = [], options: GenerationOptions = .init()) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.options = options
    }
}

/// One message in the conversation sent to a model.
struct LLMMessage: Sendable, Hashable {
    enum Role: String, Sendable, Hashable, Codable {
        case system
        case user
        case assistant
        case tool
    }

    var role: Role
    var content: String
    /// Tool calls requested by the assistant in this message.
    var toolCalls: [LLMToolCall]
    /// For `.tool` messages: the identifier of the call this result answers.
    var toolCallID: String?

    init(role: Role, content: String, toolCalls: [LLMToolCall] = [], toolCallID: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
    }

    static func system(_ content: String) -> LLMMessage { LLMMessage(role: .system, content: content) }
    static func user(_ content: String) -> LLMMessage { LLMMessage(role: .user, content: content) }
    static func assistant(_ content: String, toolCalls: [LLMToolCall] = []) -> LLMMessage {
        LLMMessage(role: .assistant, content: content, toolCalls: toolCalls)
    }
    static func tool(_ content: String, callID: String) -> LLMMessage {
        LLMMessage(role: .tool, content: content, toolCallID: callID)
    }
}

/// Sampling and runtime options. `nil` means "use the provider default".
struct GenerationOptions: Sendable, Hashable {
    var temperature: Double?
    /// Context length the runtime must allocate (Ollama `num_ctx`). Providers
    /// that cannot set it ignore it; the context manager still enforces it.
    var contextLength: Int?
    var maxOutputTokens: Int?
    var reasoning: ReasoningEffort?

    init(temperature: Double? = nil, contextLength: Int? = nil, maxOutputTokens: Int? = nil,
         reasoning: ReasoningEffort? = nil) {
        self.temperature = temperature
        self.contextLength = contextLength
        self.maxOutputTokens = maxOutputTokens
        self.reasoning = reasoning
    }
}

/// Requested reasoning depth for models that support it.
enum ReasoningEffort: String, Sendable, Hashable, Codable, CaseIterable {
    case off
    case low
    case medium
    case high
}
