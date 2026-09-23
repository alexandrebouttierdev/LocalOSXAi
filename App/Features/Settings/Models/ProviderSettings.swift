import Foundation

/// User configuration of the local model servers.
///
/// Stored in `UserDefaults`: endpoints are not secrets. Credentials for remote
/// servers, when supported, will go to the Keychain (docs/security/permissions.md).
struct ProviderSettings: Codable, Hashable, Sendable {
    struct Endpoint: Codable, Hashable, Sendable {
        var isEnabled: Bool
        var baseURL: URL
    }

    var ollama: Endpoint
    /// Context length requested from Ollama, or `nil` for automatic (the
    /// loaded size, else the conservative fallback).
    var ollamaContextTokens: Int?
    var lmStudio: Endpoint
    /// Seconds without any byte from the server before a request fails.
    var idleTimeoutSeconds: Double

    static let defaults = ProviderSettings(
        ollama: Endpoint(isEnabled: true, baseURL: staticURL("http://localhost:11434")),
        ollamaContextTokens: nil,
        lmStudio: Endpoint(isEnabled: true, baseURL: staticURL("http://localhost:1234")),
        idleTimeoutSeconds: 300
    )

    /// Stable identities of the built-in providers, shared by the factory
    /// that creates them and the views that show their status.
    static let ollamaID: ProviderID = "ollama"
    static let lmStudioID: ProviderID = "lmstudio"

    static let contextPresets = [8_192, 16_384, 32_768, 65_536, 131_072]
    static let idleTimeoutRange: ClosedRange<Double> = 30...1_800

    /// Parses a user-entered server URL. Only `http` and `https` URLs with a
    /// host are accepted; a trailing slash or `/v1` suffix is removed so both
    /// `http://localhost:1234` and `http://localhost:1234/v1/` work.
    static func serverURL(from text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if trimmed.hasSuffix("/v1") { trimmed.removeLast(3) }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.query == nil, components.fragment == nil else { return nil }
        return components.url
    }

    /// For compile-time constant URLs only.
    private static func staticURL(_ string: String) -> URL {
        guard let url = URL(string: string) else { preconditionFailure("Invalid constant URL \(string)") }
        return url
    }
}
