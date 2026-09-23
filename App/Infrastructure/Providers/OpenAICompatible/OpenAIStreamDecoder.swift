import Foundation

/// Decodes an OpenAI-compatible Server-Sent Events chat stream.
///
/// Tool calls are streamed as fragments keyed by `index`: the first fragment
/// carries the id and name, later ones append to `arguments`. The decoder
/// buffers them and emits each call once, complete, when the choice finishes
/// — as the `LLMEvent` contract requires (docs/ai/streaming.md).
struct OpenAIStreamDecoder: LLMStreamDecoder, Sendable {
    private struct PartialToolCall: Sendable {
        var id: String?
        var name = ""
        var arguments = ""
    }

    private var partialCalls: [Int: PartialToolCall] = [:]
    private var finishReason: FinishReason?
    private var usage: TokenUsage?
    private var isComplete = false
    private let makeID: @Sendable () -> String

    init(makeID: @escaping @Sendable () -> String = { "call_\(UUID().uuidString.prefix(12).lowercased())" }) {
        self.makeID = makeID
    }

    mutating func decode(line: String) throws -> [LLMEvent] {
        // SSE comments (": ping") and `event:`/`id:` fields carry no data.
        guard !isComplete, line.hasPrefix("data:") else { return [] }
        let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" {
            return completion()
        }

        let chunk: OpenAIWire.ChatChunk
        do {
            chunk = try OpenAIWire.decoder.decode(OpenAIWire.ChatChunk.self, from: Data(payload.utf8))
        } catch {
            throw ProviderError.invalidResponse("Unreadable stream event: \(payload.prefix(120))")
        }
        if let error = chunk.error {
            throw ProviderHTTP.classify(status: 500, message: error.message)
        }
        if let reported = chunk.usage, let prompt = reported.promptTokens, let completion = reported.completionTokens {
            usage = TokenUsage(promptTokens: prompt, completionTokens: completion)
        }

        var events: [LLMEvent] = []
        guard let choice = chunk.choices?.first else { return events }
        if let reasoning = choice.delta?.reasoningContent ?? choice.delta?.reasoning, !reasoning.isEmpty {
            events.append(.reasoningDelta(reasoning))
        }
        if let content = choice.delta?.content, !content.isEmpty {
            events.append(.textDelta(content))
        }
        for fragment in choice.delta?.toolCalls ?? [] {
            accumulate(fragment)
        }
        if let reason = choice.finishReason {
            finishReason = Self.finishReason(reason)
            events += flushToolCalls()
        }
        return events
    }

    /// Servers that close the stream without `[DONE]` are accepted as long as
    /// a finish reason was received; otherwise the answer was cut off.
    mutating func finish() throws -> [LLMEvent] {
        if isComplete { return [] }
        guard finishReason != nil else {
            throw ProviderError.invalidResponse("The stream ended before the model finished.")
        }
        return completion()
    }

    // MARK: Helpers

    private mutating func accumulate(_ fragment: OpenAIWire.ToolCallDelta) {
        let index = fragment.index ?? 0
        var call = partialCalls[index] ?? PartialToolCall()
        if let id = fragment.id, !id.isEmpty { call.id = id }
        if let name = fragment.function?.name { call.name += name }
        if let arguments = fragment.function?.arguments { call.arguments += arguments }
        partialCalls[index] = call
    }

    private mutating func flushToolCalls() -> [LLMEvent] {
        let events = partialCalls.sorted { $0.key < $1.key }.map { _, call in
            LLMEvent.toolCall(LLMToolCall(id: call.id ?? makeID(), name: call.name, rawArguments: call.arguments))
        }
        if !events.isEmpty { finishReason = .toolCalls }
        partialCalls = [:]
        return events
    }

    private mutating func completion() -> [LLMEvent] {
        isComplete = true
        var events = flushToolCalls()
        if let usage { events.append(.usage(usage)) }
        events.append(.finished(finishReason ?? .stop))
        return events
    }

    private static func finishReason(_ raw: String) -> FinishReason {
        switch raw {
        case "tool_calls", "function_call": .toolCalls
        case "length": .length
        default: .stop
        }
    }
}
