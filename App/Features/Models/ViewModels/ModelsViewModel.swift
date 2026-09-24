import Foundation
import Observation

/// Model discovery and selection.
@MainActor
@Observable
final class ModelsViewModel {
    private(set) var catalog: [ProviderModels] = []
    private(set) var isLoading = false
    private(set) var selectedModelID: AIModel.ID?
    /// Per-model settings; models without an entry use the defaults.
    private(set) var modelSettings: [AIModel.ID: ModelSettings] = [:]
    var error: UserFacingError?

    private let registry: ProviderRegistry
    private let settingsRepository: any ModelSettingsRepository

    init(registry: ProviderRegistry, settingsRepository: any ModelSettingsRepository) {
        self.registry = registry
        self.settingsRepository = settingsRepository
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

    /// Names of the providers that answered the last discovery, in configuration order.
    var connectedProviderNames: [String] {
        catalog.compactMap { group in
            if case .available = group.status { group.provider.displayName } else { nil }
        }
    }

    func settings(for id: AIModel.ID?) -> ModelSettings {
        id.flatMap { modelSettings[$0] } ?? .defaults
    }

    /// True when the model's provider lets the context length be chosen.
    func canSetContext(for id: AIModel.ID?) -> Bool {
        guard let id else { return false }
        return catalog.first { $0.id == id.provider }?.provider.supportsContextLength ?? false
    }

    /// What the next run sends for this model.
    func generationOptions(for id: AIModel.ID?) -> GenerationOptions {
        settings(for: id).generationOptions(canSetContext: canSetContext(for: id))
    }

    /// Context the next run will budget for this model, with its settings applied.
    func effectiveContextTokens(for model: AIModel) -> Int {
        model.contextWindow.effectiveTokens(choosing: generationOptions(for: model.id).contextLength)
    }

    func updateSettings(_ settings: ModelSettings, for id: AIModel.ID) async {
        do {
            try await settingsRepository.save(settings, for: id)
            modelSettings[id] = settings.isDefault ? nil : settings
        } catch {
            self.error = UserFacingError(error, title: "Could not save the model settings", category: .persistence)
        }
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
        do {
            modelSettings = try await settingsRepository.allSettings()
        } catch {
            self.error = UserFacingError(error, title: "Could not load the model settings", category: .persistence)
        }
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
