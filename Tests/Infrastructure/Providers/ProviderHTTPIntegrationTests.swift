import Foundation
import Testing
@testable import LocalOSXAi

/// Providers exercised through real `URLSession` requests answered by
/// `StubURLProtocol`: routing, request bodies, line reassembly, HTTP errors,
/// unreachable servers and cancellation.
@Suite("Providers over HTTP", .timeLimit(.minutes(1)))
struct ProviderHTTPIntegrationTests {
    private func ollama(_ route: StubURLProtocol.Route, contextTokens: Int? = nil) -> OllamaProvider {
        OllamaProvider(
            configuration: .init(id: "ollama", baseURL: route.baseURL, contextTokens: contextTokens, idleTimeout: 30),
            session: route.session()
        )
    }

    private func lmStudio(_ route: StubURLProtocol.Route, flavor: OpenAICompatibleProvider.Flavor = .lmStudio) -> OpenAICompatibleProvider {
        OpenAICompatibleProvider(
            configuration: .init(id: "lmstudio", displayName: "LM Studio", baseURL: route.baseURL, flavor: flavor, idleTimeout: 30),
            session: route.session()
        )
    }

    // MARK: Ollama

    @Test("Ollama lists chat models with advertised, loaded and configured context")
    func ollamaListsModels() async throws {
        let route = StubURLProtocol.route { request in
            request.path == "/api/ps" ? .json(OllamaFixtures.running) : .json(OllamaFixtures.tags)
        }
        let models = try await ollama(route, contextTokens: 32_768).listModels()

        let model = try #require(models.first)
        #expect(models.count == 1)
        #expect(model.name == "gemma4:26b")
        #expect(model.capabilities == [.streaming, .tools, .vision, .reasoning])
        #expect(model.contextWindow == ContextWindow(advertisedTokens: 262_144, loadedTokens: 65_536, configuredTokens: 32_768))
    }

    @Test("Ollama falls back to /api/show for servers without capabilities in tags")
    func ollamaShowFallback() async throws {
        let route = StubURLProtocol.route { request in
            switch request.path {
            case "/api/tags": .json(#"{"models":[{"name":"llama3:8b","details":{}}]}"#)
            case "/api/show": .json(#"{"capabilities":["completion","tools"],"model_info":{"llama.context_length":8192}}"#)
            default: .json(#"{"models":[]}"#)
            }
        }
        let model = try #require(try await ollama(route).listModels().first)

        #expect(model.supportsTools)
        #expect(model.contextWindow.advertisedTokens == 8_192)
        let show = try #require(route.requests.first { $0.path == "/api/show" })
        #expect(show.body == ["model": "llama3:8b"])
    }

    @Test("a failing /api/ps does not prevent listing")
    func ollamaWithoutRunningInfo() async throws {
        let route = StubURLProtocol.route { request in
            request.path == "/api/ps" ? .json("oops", status: 500) : .json(OllamaFixtures.tags)
        }
        let model = try #require(try await ollama(route).listModels().first)
        #expect(model.contextWindow.loadedTokens == nil)
    }

    @Test("an unreachable server is reported with its endpoint")
    func unreachable() async {
        let route = StubURLProtocol.route { _ in .failure(.cannotConnectToHost) }
        await #expect(throws: ProviderError.unreachable(endpoint: route.baseURL.absoluteString)) {
            try await ollama(route).listModels()
        }
    }

    @Test("Ollama streams a chat, reassembling lines split across network chunks")
    func ollamaStream() async throws {
        let text = OllamaFixtures.textStream
        let middle = text.index(text.startIndex, offsetBy: text.count / 2)
        let route = StubURLProtocol.route { _ in
            StubURLProtocol.Response(chunks: [String(text[..<middle]), String(text[middle...])], chunkDelay: .milliseconds(5))
        }
        let request = LLMRequest(model: "gemma4:26b", messages: [.user("Hi")], options: GenerationOptions(contextLength: 65_536))

        let result = await collect(ollama(route).stream(request: request))

        #expect(result.error == nil)
        #expect(result.elements.last == .finished(.stop))
        #expect(result.elements.compactMap { if case .textDelta(let text) = $0 { text } else { nil } }.joined() == "Hello to you!")
        let sent = try #require(route.requests.first)
        #expect(sent.method == "POST")
        #expect(sent.path == "/api/chat")
        #expect(sent.body?.objectValue?["options"] == ["num_ctx": 65_536])
    }

    @Test("an unknown model returns modelNotFound")
    func modelNotFound() async {
        let route = StubURLProtocol.route { _ in .json(#"{"error":"model 'nope' not found"}"#, status: 404) }
        let result = await collect(ollama(route).stream(request: LLMRequest(model: "nope", messages: [.user("x")])))
        #expect(result.error as? ProviderError == .modelNotFound("model 'nope' not found"))
    }

    @Test("a stream cut before completion fails")
    func truncatedStream() async {
        let route = StubURLProtocol.route { _ in .json(#"{"message":{"content":"Hel"},"done":false}"# + "\n") }
        let result = await collect(ollama(route).stream(request: LLMRequest(model: "m", messages: [.user("x")])))
        #expect(result.elements == [.textDelta("Hel")])
        #expect(result.error is ProviderError)
    }

    @Test("cancelling the consumer stops the HTTP request")
    func cancellation() async throws {
        let route = StubURLProtocol.route { _ in
            StubURLProtocol.Response(chunks: [#"{"message":{"content":"Hi"},"done":false}"# + "\n"], hangs: true)
        }
        let stream = ollama(route).stream(request: LLMRequest(model: "m", messages: [.user("x")]))
        let consumer = Task { await collect(stream) }
        try await Task.sleep(for: .milliseconds(100))
        consumer.cancel()
        _ = await consumer.value
        for _ in 0..<200 where route.stopCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(route.stopCount >= 1)
    }

    // MARK: LM Studio / OpenAI-compatible

    @Test("LM Studio lists chat models with vision, tools and the loaded context")
    func lmStudioModels() async throws {
        let route = StubURLProtocol.route { _ in .json(OpenAIFixtures.lmStudioModels) }
        let models = try await lmStudio(route).listModels()

        #expect(models.map(\.name) == ["google/gemma-4-26b-a4b-qat", "qwen3-8b"])
        let loaded = models[0]
        #expect(loaded.capabilities == [.streaming, .tools, .vision])
        #expect(loaded.contextWindow.effectiveTokens == 80_128)
        #expect(models[1].contextWindow.loadedTokens == nil)
        #expect(route.requests.map(\.path) == ["/api/v0/models"])
    }

    @Test("LM Studio falls back to the OpenAI listing when the native one is missing")
    func lmStudioFallback() async throws {
        let route = StubURLProtocol.route { request in
            request.path == "/api/v0/models" ? .json("Not Found", status: 404) : .json(OpenAIFixtures.openAIModels)
        }
        let models = try await lmStudio(route).listModels()
        #expect(models.map(\.name) == ["llama-3.2-3b"])
    }

    @Test("the generic flavor only uses the OpenAI listing")
    func genericFlavor() async throws {
        let route = StubURLProtocol.route { _ in .json(OpenAIFixtures.openAIModels) }
        _ = try await lmStudio(route, flavor: .generic).listModels()
        #expect(route.requests.map(\.path) == ["/v1/models"])
    }

    @Test("an OpenAI-compatible server streams server-sent events")
    func openAIStream() async throws {
        let route = StubURLProtocol.route { _ in StubURLProtocol.Response(chunks: [OpenAIFixtures.fragmentedToolCalls]) }
        let result = await collect(lmStudio(route).stream(request: LLMRequest(model: "m", messages: [.user("x")])))

        #expect(result.error == nil)
        #expect(result.elements.filter { if case .toolCallProgress = $0 { false } else { true } }.count == 3)
        #expect(result.elements.last == .finished(.toolCalls))
        #expect(route.requests.first?.path == "/v1/chat/completions")
    }

    @Test("server errors carry the server's message")
    func serverError() async {
        let route = StubURLProtocol.route { _ in .json(#"{"error":{"message":"Model unloaded"}}"#, status: 500) }
        let result = await collect(lmStudio(route).stream(request: LLMRequest(model: "m", messages: [.user("x")])))
        #expect(result.error as? ProviderError == .httpStatus(code: 500, message: "Model unloaded"))
    }
}
