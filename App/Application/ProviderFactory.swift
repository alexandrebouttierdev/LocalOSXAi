import Foundation
import OSLog

/// Builds the concrete providers described by the user's settings.
///
/// Lives in the composition root because it is the only code allowed to know
/// every provider type.
enum ProviderFactory {
    static func providers(for settings: ProviderSettings, secrets: any ProviderSecretStore) -> [any LLMProvider] {
        var providers: [any LLMProvider] = []
        if settings.ollama.isEnabled {
            providers.append(OllamaProvider(configuration: .init(
                id: ProviderSettings.ollamaID,
                baseURL: settings.ollama.baseURL,
                contextTokens: settings.ollamaContextTokens,
                idleTimeout: settings.idleTimeoutSeconds,
                logo: ProviderSettings.ollamaLogo
            )))
        }
        if settings.lmStudio.isEnabled {
            providers.append(OpenAICompatibleProvider(configuration: .init(
                id: ProviderSettings.lmStudioID,
                displayName: "LM Studio",
                baseURL: settings.lmStudio.baseURL,
                flavor: .lmStudio,
                idleTimeout: settings.idleTimeoutSeconds,
                logo: ProviderSettings.lmStudioLogo
            )))
        }
        for server in settings.customServers where server.isEnabled {
            providers.append(OpenAICompatibleProvider(configuration: .init(
                id: server.providerID,
                displayName: server.name,
                baseURL: server.baseURL,
                flavor: .generic,
                idleTimeout: settings.idleTimeoutSeconds,
                apiKey: apiKey(for: server, in: secrets),
                declaredCapabilities: server.supportsTools ? .tools : [],
                contextTokens: server.contextTokens
            )))
        }
        return providers
    }

    /// A key that cannot be read is logged and omitted: a server that needs
    /// it then answers 401, which the settings show next to the server.
    private static func apiKey(for server: ProviderSettings.CustomServer, in secrets: any ProviderSecretStore) -> String? {
        do {
            return try secrets.apiKey(for: server.providerID)
        } catch {
            Logger(category: .provider).error("Could not read the API key of \(server.name): \(error)")
            return nil
        }
    }
}
