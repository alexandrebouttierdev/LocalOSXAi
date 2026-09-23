import Foundation

/// `LLMProvider` for servers implementing the OpenAI chat completions API.
///
/// LM Studio is this provider with the `.lmStudio` flavor, which lists models
/// through LM Studio's native endpoint to learn their type, load state and
/// context sizes — information the OpenAI `/v1/models` endpoint lacks.
struct OpenAICompatibleProvider: LLMProvider {
    enum Flavor: Sendable {
        case generic
        case lmStudio
    }

    struct Configuration: Sendable {
        var id: ProviderID
        var displayName: String
        /// Server root, without the `/v1` suffix (e.g. `http://localhost:1234`).
        var baseURL: URL
        var flavor: Flavor
        var idleTimeout: TimeInterval
    }

    let descriptor: ProviderDescriptor
    private let configuration: Configuration
    private let session: URLSession

    init(configuration: Configuration, session: URLSession? = nil) {
        self.configuration = configuration
        self.session = session ?? ProviderHTTP.makeSession(idleTimeout: configuration.idleTimeout)
        descriptor = ProviderDescriptor(id: configuration.id, displayName: configuration.displayName, endpoint: configuration.baseURL)
    }

    // MARK: Models

    func listModels() async throws -> [AIModel] {
        if configuration.flavor == .lmStudio, let models = try await lmStudioModels() {
            return models
        }
        let data = try await ProviderHTTP.data(for: request("v1/models"), session: session)
        let response = try decode(OpenAIWire.ModelsResponse.self, from: data)
        // The OpenAI listing says nothing about capabilities or context:
        // only streaming is assumed, and embedding models are skipped by name.
        return response.data
            .filter { !$0.id.lowercased().contains("embed") }
            .map { model(named: $0.id, contextWindow: ContextWindow(), capabilities: [.streaming]) }
    }

    /// LM Studio's native listing, or `nil` when the server does not provide
    /// it (older versions), in which case the OpenAI listing is used.
    private func lmStudioModels() async throws -> [AIModel]? {
        let data: Data
        do {
            data = try await ProviderHTTP.data(for: request("api/v0/models"), session: session)
        } catch ProviderError.modelNotFound, ProviderError.httpStatus {
            return nil
        }
        let response = try decode(OpenAIWire.LMStudioModelsResponse.self, from: data)
        return response.data.compactMap { entry in
            guard entry.type == "llm" || entry.type == "vlm" else { return nil }
            var capabilities: ModelCapabilities = [.streaming]
            if entry.capabilities?.contains("tool_use") == true { capabilities.insert(.tools) }
            if entry.type == "vlm" { capabilities.insert(.vision) }
            let contextWindow = ContextWindow(
                advertisedTokens: entry.maxContextLength,
                loadedTokens: entry.state == "loaded" ? entry.loadedContextLength : nil
            )
            return model(named: entry.id, contextWindow: contextWindow, capabilities: capabilities)
        }
    }

    private func model(named name: String, contextWindow: ContextWindow, capabilities: ModelCapabilities) -> AIModel {
        AIModel(provider: descriptor.id, name: name, displayName: name, contextWindow: contextWindow, capabilities: capabilities)
    }

    // MARK: Chat

    func stream(request llmRequest: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        StreamingProvider.stream(
            request: request("v1/chat/completions", method: "POST", body: OpenAIWire.chatBody(for: llmRequest)),
            session: session,
            decoder: OpenAIStreamDecoder()
        )
    }

    // MARK: Helpers

    private func request(_ path: String, method: String = "GET", body: JSONValue? = nil) -> URLRequest {
        ProviderHTTP.request(configuration.baseURL.appending(path: path), method: method, body: body)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try OpenAIWire.decoder.decode(type, from: data)
        } catch {
            throw ProviderError.invalidResponse("Unexpected response from \(configuration.displayName): \(error.localizedDescription)")
        }
    }
}
