import Foundation

/// A source of language models: Ollama, LM Studio, any OpenAI-compatible
/// server, or a test double.
///
/// This protocol is the only way the rest of the application talks to a model.
/// It exists so the agent runtime stays provider-agnostic: adding a provider
/// means adding a conforming type in `Infrastructure/Providers`, with no change
/// to the agent. See docs/decisions/0004-provider-abstraction.md.
///
/// Conformers must be safe to call concurrently from any isolation domain.
protocol LLMProvider: Sendable {
    var descriptor: ProviderDescriptor { get }

    /// Lists the models currently available from this provider.
    ///
    /// - Throws: `ProviderError` when the provider is unreachable or answers
    ///   with an unexpected payload.
    func listModels() async throws -> [AIModel]

    /// Streams a response for `request`.
    ///
    /// Cancellation contract: when the consumer stops iterating or its task is
    /// cancelled, the provider must stop network work promptly (the stream's
    /// `onTermination` cancels the producing task). A provider that detects
    /// cancellation itself finishes the stream by throwing `CancellationError`.
    func stream(request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error>
}
