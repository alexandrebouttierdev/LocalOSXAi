import Foundation

/// `LLMProvider` for Ollama's native API.
///
/// Uses the native API rather than Ollama's OpenAI-compatible endpoint because
/// only the native one exposes model capabilities, the loaded context size
/// and `num_ctx` (docs/decisions/0004-provider-abstraction.md).
struct OllamaProvider: LLMProvider {
    struct Configuration: Sendable {
        var id: ProviderID
        var baseURL: URL
        /// Context length requested for every model, or `nil` to reuse the
        /// loaded size (or the conservative fallback).
        var contextTokens: Int?
        var idleTimeout: TimeInterval
    }

    let descriptor: ProviderDescriptor
    private let configuration: Configuration
    private let session: URLSession

    init(configuration: Configuration, session: URLSession? = nil) {
        self.configuration = configuration
        self.session = session ?? ProviderHTTP.makeSession(idleTimeout: configuration.idleTimeout)
        descriptor = ProviderDescriptor(id: configuration.id, displayName: "Ollama", endpoint: configuration.baseURL)
    }

    // MARK: Models

    func listModels() async throws -> [AIModel] {
        async let tagsData = ProviderHTTP.data(for: request("api/tags"), session: session)
        async let runningData = try? ProviderHTTP.data(for: request("api/ps"), session: session)

        let tags = try decode(OllamaWire.TagsResponse.self, from: try await tagsData)
        // `/api/ps` is best effort: without it models are simply reported as not loaded.
        let running = await runningData.flatMap { try? decode(OllamaWire.RunningResponse.self, from: $0) }
        let loadedContexts = Dictionary(
            (running?.models ?? []).compactMap { model in model.contextLength.map { (model.name, $0) } },
            uniquingKeysWith: { first, _ in first }
        )

        return try await withThrowingTaskGroup(of: AIModel?.self) { group in
            for model in tags.models {
                group.addTask { try await makeModel(model, loadedContext: loadedContexts[model.name]) }
            }
            var models: [AIModel] = []
            for try await model in group {
                if let model { models.append(model) }
            }
            return models
        }
    }

    /// Builds a model from `/api/tags`, falling back to `/api/show` for
    /// servers older than the `capabilities` field.
    private func makeModel(_ tag: OllamaWire.TagsResponse.Model, loadedContext: Int?) async throws -> AIModel? {
        var capabilityNames = tag.capabilities
        var advertised = tag.details?.contextLength
        if capabilityNames == nil || advertised == nil {
            let body: JSONValue = ["model": .string(tag.name)]
            let data = try await ProviderHTTP.data(for: request("api/show", method: "POST", body: body), session: session)
            let show = try decode(OllamaWire.ShowResponse.self, from: data)
            capabilityNames = capabilityNames ?? show.capabilities
            advertised = advertised ?? show.contextLength
        }
        guard let capabilities = OllamaWire.capabilities(from: capabilityNames ?? ["completion"]) else { return nil }
        return AIModel(
            provider: descriptor.id,
            name: tag.name,
            displayName: tag.name,
            contextWindow: ContextWindow(
                advertisedTokens: advertised,
                loadedTokens: loadedContext,
                configuredTokens: configuration.contextTokens
            ),
            capabilities: capabilities
        )
    }

    // MARK: Chat

    func stream(request llmRequest: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        StreamingProvider.stream(
            request: request("api/chat", method: "POST", body: OllamaWire.chatBody(for: llmRequest)),
            session: session,
            decoder: OllamaStreamDecoder()
        )
    }

    // MARK: Helpers

    private func request(_ path: String, method: String = "GET", body: JSONValue? = nil) -> URLRequest {
        ProviderHTTP.request(configuration.baseURL.appending(path: path), method: method, body: body)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try OllamaWire.decoder.decode(type, from: data)
        } catch {
            throw ProviderError.invalidResponse("Unexpected response from Ollama: \(error.localizedDescription)")
        }
    }
}
