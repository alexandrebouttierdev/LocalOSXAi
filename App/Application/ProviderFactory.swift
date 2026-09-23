import Foundation

/// Builds the concrete providers described by the user's settings.
///
/// Lives in the composition root because it is the only code allowed to know
/// every provider type.
enum ProviderFactory {
    static func providers(for settings: ProviderSettings) -> [any LLMProvider] {
        var providers: [any LLMProvider] = []
        if settings.ollama.isEnabled {
            providers.append(OllamaProvider(configuration: .init(
                id: ProviderSettings.ollamaID,
                baseURL: settings.ollama.baseURL,
                contextTokens: settings.ollamaContextTokens,
                idleTimeout: settings.idleTimeoutSeconds
            )))
        }
        if settings.lmStudio.isEnabled {
            providers.append(OpenAICompatibleProvider(configuration: .init(
                id: ProviderSettings.lmStudioID,
                displayName: "LM Studio",
                baseURL: settings.lmStudio.baseURL,
                flavor: .lmStudio,
                idleTimeout: settings.idleTimeoutSeconds
            )))
        }
        return providers
    }
}
