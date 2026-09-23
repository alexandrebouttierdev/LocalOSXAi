import Foundation
import Observation

/// Model discovery and selection.
@MainActor
@Observable
final class ModelsViewModel {
    private(set) var catalog: [ProviderModels] = []
    private(set) var isLoading = false
    private(set) var selectedModelID: AIModel.ID?

    private let registry: ProviderRegistry

    init(registry: ProviderRegistry) {
        self.registry = registry
    }

    var allModels: [AIModel] { catalog.flatMap(\.models) }

    var selectedModel: AIModel? {
        guard let selectedModelID else { return nil }
        return allModels.first { $0.id == selectedModelID }
    }

    /// True when at least one provider is configured but none is reachable.
    var hasNoReachableProvider: Bool {
        !catalog.isEmpty && catalog.allSatisfy { if case .unavailable = $0.status { true } else { false } }
    }

    func providerName(for id: ProviderID) -> String {
        catalog.first { $0.id == id }?.provider.displayName ?? id.rawValue
    }

    /// Rediscovers models. Keeps the current selection when the model is
    /// still available; otherwise prefers the first tool-capable model,
    /// because the agent is much less useful without tools.
    func refresh() async {
        isLoading = true
        catalog = await registry.discoverModels()
        isLoading = false

        if let selectedModel, allModels.contains(selectedModel) { return }
        let preferred = allModels.first(where: \.supportsTools) ?? allModels.first
        selectedModelID = preferred?.id
    }

    /// Replaces the providers (after a Settings change) and rediscovers models.
    func reconfigure(providers: [any LLMProvider]) async {
        await registry.configure(providers)
        await refresh()
    }

    func select(_ id: AIModel.ID) {
        guard allModels.contains(where: { $0.id == id }) else { return }
        selectedModelID = id
    }
}
