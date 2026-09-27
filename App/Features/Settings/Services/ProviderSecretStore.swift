import Foundation

/// Storage port for provider credentials. Implemented by the Keychain in
/// `Infrastructure/Settings`; secrets never go to `UserDefaults` or SQLite
/// (docs/security/permissions.md).
protocol ProviderSecretStore: Sendable {
    /// The API key saved for a provider, or `nil` when there is none.
    func apiKey(for provider: ProviderID) throws -> String?
    /// Saves a key, or removes it when `key` is `nil`. Removing a missing key
    /// succeeds.
    func setAPIKey(_ key: String?, for provider: ProviderID) throws
}
