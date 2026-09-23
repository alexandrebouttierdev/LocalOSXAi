import Foundation

/// A provider that lists a fixed simulated model so model selection can be
/// used before real providers exist (Phase 2). Its `stream` answers with a
/// single fixed message; the simulated agent does not call it.
struct SimulatedLLMProvider: LLMProvider {
    let descriptor = ProviderDescriptor(id: "simulated", displayName: "Simulated", endpoint: nil)

    func listModels() async throws -> [AIModel] {
        [
            AIModel(
                provider: descriptor.id,
                name: "simulated-agent",
                displayName: "simulated-agent",
                contextWindow: ContextWindow(advertisedTokens: 32_768),
                capabilities: [.tools, .streaming, .reasoning]
            )
        ]
    }

    func stream(request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("This is a simulated provider. Connect Ollama or LM Studio in Phase 2."))
            continuation.yield(.finished(.stop))
            continuation.finish()
        }
    }
}
