import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("ModelsViewModel")
struct ModelsViewModelTests {
    private func makeViewModel(_ models: [AIModel]) -> ModelsViewModel {
        ModelsViewModel(registry: ProviderRegistry(providers: [
            MockLLMProvider(id: "fake", displayName: "Fake", models: .success(models))
        ]))
    }

    @Test("refresh selects the first tool-capable model")
    func prefersToolModels() async {
        let viewModel = makeViewModel([Fixtures.model("a-plain"), Fixtures.model("b-tools", capabilities: [.tools])])
        await viewModel.refresh()
        #expect(viewModel.selectedModel?.name == "b-tools")
    }

    @Test("refresh falls back to the first model when none supports tools")
    func fallsBackToFirstModel() async {
        let viewModel = makeViewModel([Fixtures.model("b"), Fixtures.model("a")])
        await viewModel.refresh()
        #expect(viewModel.selectedModel?.name == "a")
    }

    @Test("refresh keeps a selection that is still available")
    func keepsSelection() async {
        let viewModel = makeViewModel([Fixtures.model("a", capabilities: [.tools]), Fixtures.model("b")])
        await viewModel.refresh()
        viewModel.select(AIModel.ID(provider: "fake", name: "b"))
        await viewModel.refresh()
        #expect(viewModel.selectedModel?.name == "b")
    }

    @Test("selecting an unknown model is ignored")
    func ignoresUnknownSelection() async {
        let viewModel = makeViewModel([Fixtures.model("a")])
        await viewModel.refresh()
        viewModel.select(AIModel.ID(provider: "other", name: "a"))
        #expect(viewModel.selectedModel?.provider == "fake")
    }

    @Test("provider names come from descriptors")
    func providerNames() async {
        let viewModel = makeViewModel([Fixtures.model("a")])
        await viewModel.refresh()
        #expect(viewModel.providerName(for: "fake") == "Fake")
        #expect(viewModel.providerName(for: "unknown") == "unknown")
    }

    @Test("reconfiguring replaces providers and rediscovers models")
    func reconfigure() async {
        let viewModel = makeViewModel([Fixtures.model("a")])
        await viewModel.refresh()
        await viewModel.reconfigure(providers: [
            MockLLMProvider(id: "other", displayName: "Other", models: .success([Fixtures.model("b", provider: "other")]))
        ])
        #expect(viewModel.allModels.map(\.name) == ["b"])
        #expect(viewModel.selectedModel?.name == "b")
    }

    @Test("reports when no configured provider is reachable")
    func noReachableProvider() async {
        let viewModel = ModelsViewModel(registry: ProviderRegistry(providers: [
            MockLLMProvider(models: .failure(.unreachable(endpoint: "http://localhost:11434")))
        ]))
        await viewModel.refresh()
        #expect(viewModel.hasNoReachableProvider)
    }

    @Test("connected providers are the ones that answered, in configuration order")
    func connectedProviders() async {
        let viewModel = ModelsViewModel(registry: ProviderRegistry(providers: [
            MockLLMProvider(id: "down", displayName: "Down", models: .failure(.unreachable(endpoint: "http://localhost:1"))),
            MockLLMProvider(id: "up", displayName: "Up", models: .success([])),
            MockLLMProvider(id: "also", displayName: "Also", models: .success([]))
        ]))
        #expect(viewModel.connectedProviders.isEmpty)
        await viewModel.refresh()
        #expect(viewModel.connectedProviders.map(\.displayName) == ["Up", "Also"])
        #expect(viewModel.provider(for: "up")?.displayName == "Up")
        #expect(viewModel.provider(for: "missing") == nil)
    }

    @Test("no models means no selection")
    func noModels() async {
        let viewModel = makeViewModel([])
        await viewModel.refresh()
        #expect(viewModel.selectedModelID == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("model settings load with discovery, save, and turn into run options")
    func modelSettings() async {
        let ollamaModel = Fixtures.model("gemma", provider: "ollama", capabilities: [.tools, .reasoning], advertised: 131_072)
        let studioModel = Fixtures.model("qwen", provider: "lmstudio", capabilities: [.tools], advertised: 131_072)
        let saved = ModelSettings(temperature: 0.3, contextTokens: 32_768)
        let repository = InMemoryModelSettingsRepository(settings: [ollamaModel.id: saved])
        let viewModel = ModelsViewModel(registry: ProviderRegistry(providers: [
            MockLLMProvider(id: "ollama", displayName: "Ollama", supportsContextLength: true, models: .success([ollamaModel])),
            MockLLMProvider(id: "lmstudio", displayName: "LM Studio", models: .success([studioModel]))
        ]), settingsRepository: repository)

        await viewModel.refresh()
        #expect(viewModel.settings(for: ollamaModel.id) == saved)
        #expect(viewModel.generationOptions(for: ollamaModel.id) == GenerationOptions(temperature: 0.3, contextLength: 32_768))
        #expect(viewModel.effectiveContextTokens(for: ollamaModel) == 32_768)

        // A provider that fixes the context at load time never gets a context override.
        await viewModel.updateSettings(ModelSettings(contextTokens: 65_536), for: studioModel.id)
        #expect(!viewModel.canSetContext(for: studioModel.id))
        #expect(viewModel.generationOptions(for: studioModel.id).contextLength == nil)
        #expect(await repository.allSettings()[studioModel.id] == ModelSettings(contextTokens: 65_536))

        await viewModel.updateSettings(.defaults, for: ollamaModel.id)
        #expect(viewModel.settings(for: ollamaModel.id).isDefault)
        #expect(await repository.allSettings()[ollamaModel.id] == nil)
    }

    @Test("the inspector sets the context length of models whose provider allows it, up to their maximum")
    func contextLength() async {
        let ollamaModel = Fixtures.model("gemma", provider: "ollama", advertised: 32_768)
        let studioModel = Fixtures.model("qwen", provider: "lmstudio", advertised: 131_072)
        let repository = InMemoryModelSettingsRepository()
        let viewModel = ModelsViewModel(registry: ProviderRegistry(providers: [
            MockLLMProvider(id: "ollama", displayName: "Ollama", supportsContextLength: true, models: .success([ollamaModel])),
            MockLLMProvider(id: "lmstudio", displayName: "LM Studio", models: .success([studioModel]))
        ]), settingsRepository: repository)
        await viewModel.refresh()

        #expect(viewModel.contextChoices(for: ollamaModel) == [8_192, 16_384, 32_768])
        #expect(viewModel.automaticContextTokens(for: ollamaModel) == ContextWindow.fallbackTokens)

        await viewModel.setContextTokens(32_768, for: ollamaModel)
        #expect(viewModel.effectiveContextTokens(for: ollamaModel) == 32_768)
        #expect(await repository.allSettings()[ollamaModel.id]?.contextTokens == 32_768)

        await viewModel.setContextTokens(nil, for: ollamaModel)
        #expect(viewModel.effectiveContextTokens(for: ollamaModel) == ContextWindow.fallbackTokens)
        #expect(await repository.allSettings()[ollamaModel.id] == nil)

        await viewModel.setContextTokens(65_536, for: studioModel)
        #expect(await repository.allSettings()[studioModel.id] == nil)
    }

    @Test("temperature and reasoning are set from the inspector, each keeping the other settings")
    func temperatureAndReasoning() async {
        let thinker = Fixtures.model("qwen3", provider: "ollama", capabilities: [.tools, .reasoning])
        let plain = Fixtures.model("llama", provider: "ollama")
        let repository = InMemoryModelSettingsRepository(settings: [thinker.id: ModelSettings(contextTokens: 16_384)])
        let viewModel = ModelsViewModel(registry: ProviderRegistry(providers: [
            MockLLMProvider(id: "ollama", displayName: "Ollama", supportsContextLength: true, models: .success([thinker, plain]))
        ]), settingsRepository: repository)
        await viewModel.refresh()

        await viewModel.setTemperature(0.4, for: thinker)
        await viewModel.setReasoning(.high, for: thinker)
        #expect(viewModel.settings(for: thinker.id) == ModelSettings(temperature: 0.4, reasoning: .high, contextTokens: 16_384))

        await viewModel.setTemperature(9, for: thinker)
        #expect(viewModel.settings(for: thinker.id).temperature == 2)
        await viewModel.setTemperature(nil, for: thinker)
        #expect(viewModel.settings(for: thinker.id).temperature == nil)

        await viewModel.setReasoning(.high, for: plain)
        #expect(viewModel.settings(for: plain.id).isDefault)
        #expect(ModelSettings.temperatureChoices.allSatisfy(ModelSettings.temperatureRange.contains))
    }

    @Test("temperatures outside the supported range are clamped when sent")
    func temperatureClamp() {
        #expect(ModelSettings(temperature: 5).generationOptions(canSetContext: false).temperature == 2)
        #expect(ModelSettings(temperature: -1).generationOptions(canSetContext: false).temperature == 0)
    }
}
