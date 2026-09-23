import Foundation
import Testing
@testable import LocalOSXAi

/// Opt-in tests against real local servers: `make test-live`.
///
/// Disabled by default so the regular suite never depends on Ollama or
/// LM Studio running. They check that the recorded fixtures still match what
/// current server versions send.
@Suite(
    "Live providers",
    .enabled(if: ProcessInfo.processInfo.environment["LOCALOSXAI_LIVE_TESTS"] == "1"),
    .timeLimit(.minutes(5))
)
struct LiveProviderTests {
    private let settings = ProviderSettings.defaults

    @Test("Ollama lists models and streams a short answer")
    func ollama() async throws {
        let provider = OllamaProvider(configuration: .init(
            id: ProviderSettings.ollamaID, baseURL: settings.ollama.baseURL, contextTokens: nil, idleTimeout: 300
        ))
        let models = try await provider.listModels()
        // Prefer a loaded model: requesting its current context avoids a reload.
        let model = try #require(models.first { $0.contextWindow.loadedTokens != nil } ?? models.first)

        let request = LLMRequest(
            model: model.name,
            messages: [.user("Reply with exactly one word: ok")],
            options: GenerationOptions(contextLength: model.contextWindow.effectiveTokens, maxOutputTokens: 256, reasoning: .off)
        )
        let result = await collect(provider.stream(request: request))

        #expect(result.error == nil)
        #expect(result.elements.last == .finished(.stop) || result.elements.last == .finished(.length))
    }

    @Test("LM Studio lists models")
    func lmStudio() async throws {
        let provider = OpenAICompatibleProvider(configuration: .init(
            id: ProviderSettings.lmStudioID, displayName: "LM Studio", baseURL: settings.lmStudio.baseURL,
            flavor: .lmStudio, idleTimeout: 30
        ))
        let models = try await provider.listModels()
        #expect(!models.isEmpty)
        #expect(models.allSatisfy { !$0.name.contains("embed") })
    }
}
