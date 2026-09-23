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

    @Test("no models means no selection")
    func noModels() async {
        let viewModel = makeViewModel([])
        await viewModel.refresh()
        #expect(viewModel.selectedModelID == nil)
        #expect(!viewModel.isLoading)
    }
}
