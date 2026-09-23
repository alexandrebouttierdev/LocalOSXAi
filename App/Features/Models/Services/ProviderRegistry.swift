import Foundation

/// Models offered by one provider, or why they could not be listed.
struct ProviderModels: Identifiable, Hashable, Sendable {
    enum Status: Hashable, Sendable {
        case available([AIModel])
        case unavailable(reason: String)
    }

    let provider: ProviderDescriptor
    let status: Status

    var id: ProviderID { provider.id }

    var models: [AIModel] {
        if case .available(let models) = status { return models }
        return []
    }
}

/// The configured providers and the models last discovered from them.
///
/// An actor because it is read by the agent runtime off the main actor
/// (`ModelResolving`) and reconfigured from Settings. Providers are queried
/// concurrently and independently: a stopped LM Studio must not prevent
/// Ollama models from being listed.
actor ProviderRegistry: ModelResolving {
    private var providers: [any LLMProvider]
    private var models: [AIModel.ID: AIModel] = [:]
    /// Incremented on every reconfiguration so a discovery that started
    /// before it cannot overwrite the new state when it completes.
    private var generation = 0

    init(providers: [any LLMProvider]) {
        self.providers = providers
    }

    func configure(_ providers: [any LLMProvider]) {
        self.providers = providers
        models = [:]
        generation += 1
    }

    /// Lists models from every provider, in configuration order, sorted by name.
    func discoverModels() async -> [ProviderModels] {
        let snapshot = providers
        let startedGeneration = generation

        let catalog = await withTaskGroup(of: (Int, ProviderModels).self) { group in
            for (index, provider) in snapshot.enumerated() {
                group.addTask { (index, await Self.discover(provider)) }
            }
            var results: [(Int, ProviderModels)] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }

        if startedGeneration == generation {
            models = Dictionary(catalog.flatMap(\.models).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        return catalog
    }

    func resolve(_ id: AIModel.ID) -> ResolvedModel? {
        guard let model = models[id], let provider = providers.first(where: { $0.descriptor.id == id.provider }) else {
            return nil
        }
        return ResolvedModel(model: model, provider: provider)
    }

    private static func discover(_ provider: any LLMProvider) async -> ProviderModels {
        do {
            let models = try await provider.listModels()
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            return ProviderModels(provider: provider.descriptor, status: .available(models))
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? "Models could not be listed."
            return ProviderModels(provider: provider.descriptor, status: .unavailable(reason: reason))
        }
    }
}
