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
    }
}

@MainActor
@Suite("ProviderSettingsViewModel")
struct ProviderSettingsViewModelTests {
    private func makeViewModel(store: InMemoryProviderSettingsStore = InMemoryProviderSettingsStore(),
                               applied: Recorder<ProviderSettings> = Recorder()) -> ProviderSettingsViewModel {
        ProviderSettingsViewModel(store: store) { settings in applied.record(settings) }
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
}
