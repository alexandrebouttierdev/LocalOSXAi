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

/// Aggregates model discovery across all configured providers.
///
/// Providers are queried concurrently and independently: a stopped LM Studio
/// must not prevent Ollama models from being listed.
struct ModelCatalog: Sendable {
    let providers: [any LLMProvider]

    /// Returns one entry per provider, in configuration order, with models
    /// sorted by display name.
    func loadAll() async -> [ProviderModels] {
        await withTaskGroup(of: (Int, ProviderModels).self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask {
                    (index, await Self.load(provider))
                }
            }
            var results: [(Int, ProviderModels)] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private static func load(_ provider: any LLMProvider) async -> ProviderModels {
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
