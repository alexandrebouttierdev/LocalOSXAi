import Foundation
import Observation

/// Model discovery and selection.
@MainActor
@Observable
final class ModelsViewModel {
    private(set) var catalog: [ProviderModels] = []
    private(set) var isLoading = false
    private(set) var selectedModelID: AIModel.ID?

    private let modelCatalog: ModelCatalog

    init(catalog: ModelCatalog) {
        self.modelCatalog = catalog
    }

    var allModels: [AIModel] { catalog.flatMap(\.models) }

    var selectedModel: AIModel? {
        guard let selectedModelID else { return nil }
        return allModels.first { $0.id == selectedModelID }
    }

    func providerName(for id: ProviderID) -> String {
        catalog.first { $0.id == id }?.provider.displayName ?? id.rawValue
    }

    /// Reloads all providers. Keeps the current selection when the model is
    /// still available; otherwise prefers the first tool-capable model,
    /// because the agent is much less useful without tools.
    func refresh() async {
        isLoading = true
        catalog = await modelCatalog.loadAll()
        isLoading = false

        if let selectedModel, allModels.contains(selectedModel) { return }
        let preferred = allModels.first(where: \.supportsTools) ?? allModels.first
        selectedModelID = preferred?.id
    }

    func select(_ id: AIModel.ID) {
        guard allModels.contains(where: { $0.id == id }) else { return }
        selectedModelID = id
    }
}
