import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ProviderRegistry")
struct ProviderRegistryTests {
    private let ollama = MockLLMProvider(id: "ollama", displayName: "Ollama", models: .success([
        Fixtures.model("qwen3:8b", provider: "ollama"), Fixtures.model("gpt-oss:20b", provider: "ollama")
    ]))

    @Test("keeps provider order and sorts models by display name")
    func ordering() async {
        let lmStudio = MockLLMProvider(id: "lmstudio", displayName: "LM Studio", models: .success([
            Fixtures.model("mistral", provider: "lmstudio")
        ]))
        let catalog = await ProviderRegistry(providers: [ollama, lmStudio]).discoverModels()

        #expect(catalog.map(\.provider.displayName) == ["Ollama", "LM Studio"])
        #expect(catalog[0].models.map(\.name) == ["gpt-oss:20b", "qwen3:8b"])
    }

    @Test("an unreachable provider does not hide the others")
    func failureIsolation() async {
        let down = MockLLMProvider(id: "lmstudio", displayName: "LM Studio",
                                   models: .failure(.unreachable(endpoint: "http://localhost:1234")))
        let catalog = await ProviderRegistry(providers: [down, ollama]).discoverModels()

        guard case .unavailable(let reason) = catalog[0].status else {
            Issue.record("Expected LM Studio to be unavailable")
            return
        }
        #expect(reason.contains("localhost:1234"))
        #expect(catalog[1].models.count == 2)
    }

    @Test("resolves models to their provider, even before discovery")
    func resolution() async throws {
        let registry = ProviderRegistry(providers: [ollama])
        let id = AIModel.ID(provider: "ollama", name: "qwen3:8b")

        let resolved = try #require(await registry.resolve(id))
        #expect(resolved.model.name == "qwen3:8b")
        #expect(resolved.provider.descriptor.id == "ollama")
        #expect(await registry.resolve(AIModel.ID(provider: "lmstudio", name: "qwen3:8b")) == nil)
    }

    @Test("resolving refreshes the model, picking up the context it was loaded with")
    func resolveRefreshes() async throws {
        let loaded = AIModel(provider: "lmstudio", name: "gemma", displayName: "gemma",
                             contextWindow: ContextWindow(advertisedTokens: 262_144, loadedTokens: 80_128), capabilities: [.streaming])
        let provider = MockLLMProvider(id: "lmstudio", displayName: "LM Studio", models: .success([loaded]))
        let registry = ProviderRegistry(providers: [provider])

        let resolved = try #require(await registry.resolve(loaded.id))
        #expect(resolved.model.contextWindow.effectiveTokens == 80_128)
        #expect(provider.listModelsCallCount == 1)
    }

    @Test("reconfiguring forgets models of removed providers")
    func reconfigure() async {
        let registry = ProviderRegistry(providers: [ollama])
        _ = await registry.discoverModels()
        await registry.configure([])

        #expect(await registry.resolve(AIModel.ID(provider: "ollama", name: "qwen3:8b")) == nil)
        #expect(await registry.discoverModels().isEmpty)
    }
}
