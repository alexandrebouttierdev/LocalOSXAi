import Foundation

/// A stateful decoder turning server stream lines into `LLMEvent`s.
///
/// Decoders are pure (no I/O), which is what makes every provider's wire
/// format testable from recorded fixtures.
protocol LLMStreamDecoder {
    /// Events produced by one line. Blank or irrelevant lines produce none.
    mutating func decode(line: String) throws -> [LLMEvent]
    /// Called when the byte stream ends. Returns trailing events, or throws
    /// if the stream ended before the server signalled completion.
    mutating func finish() throws -> [LLMEvent]
}

enum StreamingProvider {
    /// Runs a streaming HTTP request through `decoder`, honoring the
    /// `LLMProvider` streaming and cancellation contracts.
    static func stream<Decoder: LLMStreamDecoder & Sendable>(
        request: URLRequest,
        session: URLSession,
        decoder: Decoder
    ) -> AsyncThrowingStream<LLMEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var decoder = decoder
                do {
                    for try await line in try await ProviderHTTP.lines(for: request, session: session) {
                        try Task.checkCancellation()
                        for event in try decoder.decode(line: line) { continuation.yield(event) }
                    }
                    try Task.checkCancellation()
                    for event in try decoder.finish() { continuation.yield(event) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ProviderHTTP.translate(error, request: request))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
