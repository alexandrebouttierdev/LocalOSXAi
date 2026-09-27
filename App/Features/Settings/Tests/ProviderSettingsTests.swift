import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ProviderSettings")
struct ProviderSettingsTests {
    @Test(
        "server URLs are normalized",
        arguments: [
            ("http://localhost:11434", "http://localhost:11434"),
            ("  http://localhost:1234/  ", "http://localhost:1234"),
            ("http://localhost:1234/v1", "http://localhost:1234"),
            ("http://localhost:1234/v1/", "http://localhost:1234"),
            ("https://models.example.com", "https://models.example.com")
        ]
    )
    func validURLs(input: String, expected: String) {
        #expect(ProviderSettings.serverURL(from: input)?.absoluteString == expected)
    }

    @Test("invalid server URLs are rejected", arguments: ["", "localhost:11434", "ftp://host", "http://", "http://h?x=1", "not a url"])
    func invalidURLs(input: String) {
        #expect(ProviderSettings.serverURL(from: input) == nil)
    }

    @Test("defaults point at the standard local ports")
    func defaults() {
        #expect(ProviderSettings.defaults.ollama.baseURL.absoluteString == "http://localhost:11434")
        #expect(ProviderSettings.defaults.lmStudio.baseURL.absoluteString == "http://localhost:1234")
        #expect(ProviderSettings.defaults.ollamaContextTokens == nil)
        #expect(ProviderSettings.defaults.customServers.isEmpty)
    }

    @Test("settings saved before custom servers existed still decode")
    func legacyFormat() throws {
        let json = """
            {"ollama":{"isEnabled":true,"baseURL":"http://localhost:11434"},"ollamaContextTokens":16384,
             "lmStudio":{"isEnabled":false,"baseURL":"http://localhost:1234"},"idleTimeoutSeconds":120}
            """
        let settings = try JSONDecoder().decode(ProviderSettings.self, from: Data(json.utf8))
        #expect(settings.ollamaContextTokens == 16_384)
        #expect(!settings.lmStudio.isEnabled)
        #expect(settings.idleTimeoutSeconds == 120)
        #expect(settings.customServers.isEmpty)
    }

    @Test("custom servers round-trip and keep a provider ID derived from their identity only")
    func customServerRoundTrip() throws {
        let id = try #require(UUID(uuidString: "A1B2C3D4-0000-4000-8000-000000000001"))
        var settings = ProviderSettings.defaults
        settings.customServers = [.init(id: id, name: "llama.cpp", isEnabled: true,
                                        baseURL: ProviderSettings.customServerDefaultURL,
                                        supportsTools: false, contextTokens: 32_768)]

        let decoded = try JSONDecoder().decode(ProviderSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded == settings)
        #expect(decoded.customServers[0].providerID == "server-a1b2c3d4-0000-4000-8000-000000000001")
        var renamed = decoded.customServers[0]
        renamed.name = "Other"
        #expect(renamed.providerID == decoded.customServers[0].providerID)
    }

    @Test(
        "only loopback hosts count as this Mac",
        arguments: [
            ("http://localhost:1234", true),
            ("http://127.0.0.1:8080", true),
            ("http://[::1]:8080", true),
            ("http://app.localhost", true),
            ("http://192.168.1.20:11434", false),
            ("http://mac-studio.local:1234", false),
            ("https://api.example.com", false),
            ("http://127.example.com", false)
        ]
    )
    func onThisMac(input: String, expected: Bool) throws {
        let url = try #require(URL(string: input))
        #expect(ProviderSettings.isOnThisMac(url) == expected)
    }
}

@MainActor
@Suite("ProviderSettingsViewModel")
struct ProviderSettingsViewModelTests {
    private func makeViewModel(store: InMemoryProviderSettingsStore = InMemoryProviderSettingsStore(),
                               secrets: any ProviderSecretStore = InMemoryProviderSecretStore(),
                               applied: Recorder<ProviderSettings> = Recorder()) -> ProviderSettingsViewModel {
        ProviderSettingsViewModel(store: store, secrets: secrets) { settings in applied.record(settings) }
    }

    private func settings(with servers: [ProviderSettings.CustomServer]) -> ProviderSettings {
        var settings = ProviderSettings.defaults
        settings.customServers = servers
        return settings
    }

    private func server(_ name: String = "vLLM", url: String = "http://localhost:8000") -> ProviderSettings.CustomServer {
        .init(id: UUID(), name: name, isEnabled: true,
              baseURL: ProviderSettings.serverURL(from: url) ?? ProviderSettings.customServerDefaultURL,
              supportsTools: true, contextTokens: nil)
    }

    @Test("starts from the stored settings without changes")
    func initialState() {
        var stored = ProviderSettings.defaults
        stored.lmStudio.isEnabled = false
        let viewModel = makeViewModel(store: InMemoryProviderSettingsStore(stored))
        #expect(!viewModel.lmStudioEnabled)
        #expect(!viewModel.hasChanges)
    }

    @Test("applying valid edits saves them and reconfigures providers")
    func applyValid() async {
        let store = InMemoryProviderSettingsStore()
        let applied = Recorder<ProviderSettings>()
        let viewModel = makeViewModel(store: store, applied: applied)
        viewModel.ollamaURL = "http://192.168.1.20:11434/"
        viewModel.ollamaContextTokens = 32_768
        #expect(viewModel.hasChanges)

        #expect(await viewModel.apply())

        #expect(store.load().ollama.baseURL.absoluteString == "http://192.168.1.20:11434")
        #expect(store.load().ollamaContextTokens == 32_768)
        #expect(applied.values == [store.load()])
        #expect(viewModel.ollamaURL == "http://192.168.1.20:11434")
        #expect(!viewModel.hasChanges)
    }

    @Test("invalid URLs block applying and are reported per field")
    func applyInvalid() async {
        let store = InMemoryProviderSettingsStore()
        let applied = Recorder<ProviderSettings>()
        let viewModel = makeViewModel(store: store, applied: applied)
        viewModel.lmStudioURL = "localhost"

        #expect(await !viewModel.apply())

        #expect(viewModel.validationErrors[.lmStudioURL] != nil)
        #expect(viewModel.validationErrors[.ollamaURL] == nil)
        #expect(store.load() == .defaults)
        #expect(applied.values.isEmpty)
    }

    @Test("the timeout is clamped to the allowed range")
    func timeoutClamp() {
        let viewModel = makeViewModel()
        viewModel.idleTimeoutSeconds = 5
        #expect(viewModel.draft?.idleTimeoutSeconds == ProviderSettings.idleTimeoutRange.lowerBound)
    }

    @Test("revert discards edits and restore defaults resets them")
    func revertAndDefaults() {
        var stored = ProviderSettings.defaults
        stored.ollama.isEnabled = false
        let viewModel = makeViewModel(store: InMemoryProviderSettingsStore(stored))
        viewModel.ollamaURL = "bad"
        viewModel.revert()
        #expect(viewModel.ollamaURL == stored.ollama.baseURL.absoluteString)
        #expect(viewModel.validationErrors.isEmpty)

        viewModel.restoreDefaults()
        #expect(viewModel.ollamaEnabled)
        #expect(viewModel.hasChanges)
    }

    // MARK: Custom servers

    @Test("an added server gets a unique name and the llama.cpp port, and is saved with its key")
    func addServer() async throws {
        let store = InMemoryProviderSettingsStore()
        let secrets = InMemoryProviderSecretStore()
        let applied = Recorder<ProviderSettings>()
        let viewModel = makeViewModel(store: store, secrets: secrets, applied: applied)

        viewModel.addServer()
        viewModel.addServer()
        #expect(viewModel.customServers.map(\.name) == ["Custom Server", "Custom Server 2"])
        #expect(viewModel.customServers[0].url == "http://localhost:8080")
        viewModel.customServers[0].apiKey = "  sk-local  "
        viewModel.customServers[0].contextTokens = 32_768

        #expect(await viewModel.apply())

        let saved = store.load().customServers
        #expect(saved.map(\.name) == ["Custom Server", "Custom Server 2"])
        #expect(saved[0].contextTokens == 32_768)
        #expect(saved[0].supportsTools)
        #expect(secrets.apiKey(for: saved[0].providerID) == "sk-local")
        #expect(secrets.apiKey(for: saved[1].providerID) == nil)
        #expect(applied.values.count == 1)
        #expect(!viewModel.hasChanges)
    }

    @Test("API keys never reach the stored settings")
    func keysStayOutOfSettings() async throws {
        let store = InMemoryProviderSettingsStore()
        let viewModel = makeViewModel(store: store)
        viewModel.addServer()
        viewModel.customServers[0].apiKey = "sk-secret-value"
        #expect(await viewModel.apply())

        let json = try #require(String(bytes: JSONEncoder().encode(store.load()), encoding: .utf8))
        #expect(!json.contains("sk-secret-value"))
    }

    @Test("stored keys are shown, and editing only a key is a change that applies")
    func editKey() async {
        let existing = server()
        let secrets = InMemoryProviderSecretStore([existing.providerID: "old"])
        let viewModel = makeViewModel(store: InMemoryProviderSettingsStore(settings(with: [existing])), secrets: secrets)
        #expect(viewModel.customServers[0].apiKey == "old")
        #expect(!viewModel.hasChanges)

        viewModel.customServers[0].apiKey = "new"
        #expect(viewModel.hasChanges)
        #expect(await viewModel.apply())
        #expect(secrets.apiKey(for: existing.providerID) == "new")

        viewModel.customServers[0].apiKey = ""
        #expect(await viewModel.apply())
        #expect(secrets.apiKey(for: existing.providerID) == nil)
    }

    @Test("removing a server deletes its key on apply, not before")
    func removeServer() async {
        let existing = server()
        let secrets = InMemoryProviderSecretStore([existing.providerID: "key"])
        let store = InMemoryProviderSettingsStore(settings(with: [existing]))
        let viewModel = makeViewModel(store: store, secrets: secrets)

        viewModel.removeServer(id: existing.id)
        #expect(viewModel.customServers.isEmpty)
        #expect(secrets.apiKey(for: existing.providerID) == "key")
        #expect(viewModel.hasChanges)

        #expect(await viewModel.apply())
        #expect(store.load().customServers.isEmpty)
        #expect(secrets.apiKey(for: existing.providerID) == nil)
    }

    @Test("empty, duplicate and built-in names and invalid URLs are reported per server")
    func invalidServers() async {
        let store = InMemoryProviderSettingsStore()
        let applied = Recorder<ProviderSettings>()
        let viewModel = makeViewModel(store: store, applied: applied)
        viewModel.addServer()
        viewModel.addServer()
        viewModel.addServer()
        let ids = viewModel.customServers.map(\.id)
        viewModel.customServers[0].name = "  "
        viewModel.customServers[1].name = "lm studio"
        viewModel.customServers[2].url = "localhost:8080"

        #expect(viewModel.draft == nil)
        #expect(await !viewModel.apply())

        #expect(viewModel.validationErrors[.serverName(ids[0])] == "Enter a name")
        #expect(viewModel.validationErrors[.serverName(ids[1])] == "Another provider already uses this name")
        #expect(viewModel.validationErrors[.serverURL(ids[2])] != nil)
        #expect(viewModel.validationErrors[.serverName(ids[2])] == nil)
        #expect(store.load() == .defaults)
        #expect(applied.values.isEmpty)

        viewModel.removeServer(id: ids[2])
        #expect(viewModel.validationErrors[.serverURL(ids[2])] == nil)
    }

    @Test("a key that could not be read is reported and never deleted by applying other edits")
    func unreadableKey() async {
        let existing = server()
        let secrets = FailingProviderSecretStore([existing.providerID: "kept"], failsReads: true)
        let viewModel = makeViewModel(store: InMemoryProviderSettingsStore(settings(with: [existing])), secrets: secrets)
        #expect(viewModel.error?.title == "Could not read an API key")
        #expect(!viewModel.hasChanges)

        viewModel.idleTimeoutSeconds = 600
        #expect(await viewModel.apply())
        #expect(secrets.storedKey(for: existing.providerID) == "kept")
    }

    @Test("a Keychain write failure saves nothing and is reported")
    func keyWriteFailure() async {
        let store = InMemoryProviderSettingsStore()
        let applied = Recorder<ProviderSettings>()
        let viewModel = makeViewModel(store: store, secrets: FailingProviderSecretStore(failsWrites: true), applied: applied)
        viewModel.addServer()
        viewModel.customServers[0].apiKey = "key"

        #expect(await !viewModel.apply())

        #expect(viewModel.error?.title == "Could not save settings")
        #expect(store.load() == .defaults)
        #expect(applied.values.isEmpty)
        #expect(viewModel.hasChanges)
    }

    @Test("revert restores removed servers and their keys")
    func revertServers() {
        let existing = server()
        let secrets = InMemoryProviderSecretStore([existing.providerID: "key"])
        let viewModel = makeViewModel(store: InMemoryProviderSettingsStore(settings(with: [existing])), secrets: secrets)
        viewModel.customServers[0].apiKey = "edited"
        viewModel.addServer()

        viewModel.revert()

        #expect(viewModel.customServers.map(\.id) == [existing.id])
        #expect(viewModel.customServers[0].apiKey == "key")
        #expect(!viewModel.hasChanges)
    }

    @Test("servers outside this Mac get a privacy warning, stronger for a key over HTTP")
    func privacyWarnings() {
        let viewModel = makeViewModel()
        #expect(viewModel.privacyWarning(forURL: "http://localhost:8080") == nil)
        #expect(viewModel.privacyWarning(forURL: "not a url") == nil)

        let lan = viewModel.privacyWarning(forURL: "http://192.168.1.20:8080")
        #expect(lan?.contains("192.168.1.20") == true)
        #expect(lan?.contains("unencrypted") == false)
        #expect(viewModel.privacyWarning(forURL: "http://192.168.1.20:8080", apiKey: "k")?.contains("unencrypted") == true)
        #expect(viewModel.privacyWarning(forURL: "https://models.example.com", apiKey: "k")?.contains("unencrypted") == false)
    }
}
