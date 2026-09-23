import Foundation
import Testing
@testable import LocalOSXAi

@Suite("UserDefaultsProviderSettingsStore")
struct ProviderSettingsStoreTests {
    private func withSuite(_ body: (String) throws -> Void) rethrows {
        let suite = "LocalOSXAiTests-\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        try body(suite)
    }

    @Test("returns defaults when nothing is saved, then round-trips saved settings")
    func roundTrip() throws {
        try withSuite { suite in
            let store = UserDefaultsProviderSettingsStore(suiteName: suite)
            #expect(store.load() == .defaults)

            var settings = ProviderSettings.defaults
            settings.ollamaContextTokens = 16_384
            settings.lmStudio.isEnabled = false
            try store.save(settings)

            #expect(UserDefaultsProviderSettingsStore(suiteName: suite).load() == settings)
        }
    }

    @Test("unreadable data falls back to defaults")
    func corruptData() {
        withSuite { suite in
            UserDefaults(suiteName: suite)?.set(Data("garbage".utf8), forKey: UserDefaultsProviderSettingsStore.key)
            #expect(UserDefaultsProviderSettingsStore(suiteName: suite).load() == .defaults)
        }
    }
}
