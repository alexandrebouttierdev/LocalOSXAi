import Foundation

/// Decodes Ollama's NDJSON chat stream (one JSON object per line).
///
/// Tool calls arrive whole, without an id on older servers and with
/// arguments as an object; they are normalized into `LLMToolCall` with a
/// generated id and serialized arguments.
struct OllamaStreamDecoder: LLMStreamDecoder, Sendable {
    private var sawToolCall = false
    private var isFinished = false
    private let makeID: @Sendable () -> String

    init(makeID: @escaping @Sendable () -> String = { "call_\(UUID().uuidString.prefix(12).lowercased())" }) {
        self.makeID = makeID
    }

    mutating func decode(line: String) throws -> [LLMEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let chunk: OllamaWire.ChatChunk
        do {
            chunk = try OllamaWire.decoder.decode(OllamaWire.ChatChunk.self, from: Data(trimmed.utf8))
        } catch {
            throw ProviderError.invalidResponse("Unreadable stream line: \(trimmed.prefix(120))")
        }
        if let message = chunk.error {
            throw ProviderHTTP.classify(status: 500, message: message)
        }

        var events: [LLMEvent] = []
        if let thinking = chunk.message?.thinking, !thinking.isEmpty {
            events.append(.reasoningDelta(thinking))
        }
        if let content = chunk.message?.content, !content.isEmpty {
            events.append(.textDelta(content))
        }
        for call in chunk.message?.toolCalls ?? [] {
            sawToolCall = true
            let arguments = call.function.arguments ?? [:]
            events.append(.toolCall(LLMToolCall(
                id: call.id ?? makeID(),
                name: call.function.name,
                rawArguments: arguments.serialized()
            )))
        }
        if chunk.done == true {
            isFinished = true
            if let prompt = chunk.promptEvalCount, let completion = chunk.evalCount {
                events.append(.usage(TokenUsage(promptTokens: prompt, completionTokens: completion)))
            }
            events.append(.finished(finishReason(chunk.doneReason)))
        }
        return events
    }

    mutating func finish() throws -> [LLMEvent] {
        guard isFinished else { throw ProviderError.invalidResponse("The stream ended before the model finished.") }
        return []
    }

    private func finishReason(_ doneReason: String?) -> FinishReason {
        if sawToolCall { return .toolCalls }
        return doneReason == "length" ? .length : .stop
    }
}
