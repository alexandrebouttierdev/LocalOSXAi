import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("ModelsViewModel")
struct ModelsViewModelTests {
    private func makeViewModel(_ models: [AIModel]) -> ModelsViewModel {
        ModelsViewModel(catalog: ModelCatalog(providers: [
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

    @Test("no models means no selection")
    func noModels() async {
        let viewModel = makeViewModel([])
        await viewModel.refresh()
        #expect(viewModel.selectedModelID == nil)
        #expect(!viewModel.isLoading)
    }
}
