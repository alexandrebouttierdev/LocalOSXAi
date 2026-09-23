import Foundation

/// An incremental event emitted while a model generates a response.
///
/// Every provider normalizes its stream into this sequence. Contract (see
/// docs/ai/streaming.md):
/// - text and reasoning arrive as deltas, in order;
/// - a tool call is emitted once, fully assembled, even if the wire format
///   streams its arguments in fragments;
/// - `.finished` is the last event of a successful stream;
/// - failures terminate the stream by throwing, never through an event.
enum LLMEvent: Sendable, Hashable {
    case textDelta(String)
    case reasoningDelta(String)
    case toolCall(LLMToolCall)
    /// A tool call still being generated. Informational only (the complete
    /// call still arrives as `.toolCall`), so the UI can show progress while
    /// a model writes a large argument such as a whole file.
    case toolCallProgress(ToolCallProgress)
    case usage(TokenUsage)
    case finished(FinishReason)
}

/// A tool invocation requested by a model.
///
/// Arguments are kept as the raw text produced by the model: parsing happens
/// later, in tool validation, so a malformed call can be reported back to the
/// model instead of crashing the stream.
struct LLMToolCall: Sendable, Hashable, Codable, Identifiable {
    /// Provider-assigned call identifier, or a generated one when the provider
    /// does not supply any (Ollama does not).
    let id: String
    let name: String
    let rawArguments: String
}

/// Progress of a tool call whose arguments are still streaming.
struct ToolCallProgress: Sendable, Hashable {
    /// Position of the call in the response (several calls can stream).
    let index: Int
    let name: String
    /// Characters of arguments received so far.
    let characters: Int
    /// The beginning of the arguments (at most `prefixLength` characters),
    /// enough to recognize e.g. the target path.
    let argumentsPrefix: String

    static let prefixLength = 400
}

/// Token accounting reported by the provider, when available.
struct TokenUsage: Sendable, Hashable, Codable {
    var promptTokens: Int
    var completionTokens: Int

    var totalTokens: Int { promptTokens + completionTokens }
}

/// Why the model stopped generating.
enum FinishReason: String, Sendable, Hashable, Codable {
    /// The model completed its answer.
    case stop
    /// The output limit or the context window was reached.
    case length
    /// The model stopped to let the caller execute tool calls.
    case toolCalls
}
