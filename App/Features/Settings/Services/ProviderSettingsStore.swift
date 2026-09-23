import Foundation

/// Storage port for provider settings. Implemented in `Infrastructure/Settings`.
protocol ProviderSettingsStore: Sendable {
    /// Returns the saved settings, or `ProviderSettings.defaults` when nothing
    /// was saved or the saved data cannot be read.
    func load() -> ProviderSettings
    func save(_ settings: ProviderSettings) throws
}
