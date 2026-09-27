import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ProviderFactory")
struct ProviderFactoryTests {
    private func server(_ name: String, enabled: Bool = true) -> ProviderSettings.CustomServer {
        .init(id: UUID(), name: name, isEnabled: enabled, baseURL: ProviderSettings.customServerDefaultURL,
              supportsTools: true, contextTokens: nil)
    }

    @Test("builds the enabled built-in providers and custom servers, in settings order")
    func enabledProviders() {
        var settings = ProviderSettings.defaults
        settings.lmStudio.isEnabled = false
        let vllm = server("vLLM")
        let llama = server("llama.cpp")
        settings.customServers = [vllm, server("Off", enabled: false), llama]

        let providers = ProviderFactory.providers(for: settings, secrets: InMemoryProviderSecretStore())

        #expect(providers.map(\.descriptor.id) == [ProviderSettings.ollamaID, vllm.providerID, llama.providerID])
        #expect(providers.map(\.descriptor.displayName) == ["Ollama", "vLLM", "llama.cpp"])
        #expect(providers[1].descriptor.endpoint == ProviderSettings.customServerDefaultURL)
    }

    @Test("built-in providers carry their logo; custom servers get the generic icon")
    func logos() {
        var settings = ProviderSettings.defaults
        settings.customServers = [server("vLLM")]
        let logos = ProviderFactory.providers(for: settings, secrets: InMemoryProviderSecretStore()).map(\.descriptor.logo)
        #expect(logos == [ProviderSettings.ollamaLogo, ProviderSettings.lmStudioLogo, nil])
    }

    @Test("a key that cannot be read still builds the server")
    func unreadableKey() {
        var settings = ProviderSettings.defaults
        settings.customServers = [server("vLLM")]
        let providers = ProviderFactory.providers(for: settings, secrets: FailingProviderSecretStore(failsReads: true))
        #expect(providers.map(\.descriptor.displayName).contains("vLLM"))
    }
}
