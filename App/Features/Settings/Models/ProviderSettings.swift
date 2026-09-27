import Foundation

/// User configuration of the local model servers.
///
/// Stored in `UserDefaults`: endpoints are not secrets. API keys of custom
/// servers live in the Keychain only (`ProviderSecretStore`,
/// docs/security/permissions.md).
struct ProviderSettings: Codable, Hashable, Sendable {
    struct Endpoint: Codable, Hashable, Sendable {
        var isEnabled: Bool
        var baseURL: URL
    }

    /// A user-added server implementing the OpenAI chat completions API
    /// (llama.cpp, vLLM, Jan, LocalAI…).
    ///
    /// Such servers list model names only, so what the app cannot learn from
    /// them is declared here by the user (ADR 0021).
    struct CustomServer: Codable, Hashable, Sendable, Identifiable {
        let id: UUID
        var name: String
        var isEnabled: Bool
        var baseURL: URL
        /// Whether its models are offered tools. Declared, not trusted: every
        /// tool call is validated anyway (docs/ai/model-capabilities.md).
        var supportsTools: Bool
        /// Context length the server was started with, or `nil` for the
        /// conservative fallback.
        var contextTokens: Int?

        /// Stable across renames and URL changes, so per-model settings and
        /// the Keychain item survive them.
        var providerID: ProviderID { Self.providerID(for: id) }

        static func providerID(for id: UUID) -> ProviderID {
            ProviderID(rawValue: "server-\(id.uuidString.lowercased())")
        }
    }

    var ollama: Endpoint
    /// Context length requested from Ollama, or `nil` for automatic (the
    /// loaded size, else the conservative fallback).
    var ollamaContextTokens: Int?
    var lmStudio: Endpoint
    /// Seconds without any byte from the server before a request fails.
    var idleTimeoutSeconds: Double
    /// Added in Phase 7. Absent from settings saved before, which decode as
    /// no custom server: the format stays `providers.v1`.
    var customServers: [CustomServer] = []

    static let defaults = ProviderSettings(
        ollama: Endpoint(isEnabled: true, baseURL: staticURL("http://localhost:11434")),
        ollamaContextTokens: nil,
        lmStudio: Endpoint(isEnabled: true, baseURL: staticURL("http://localhost:1234")),
        idleTimeoutSeconds: 300
    )

    /// Suggested for a new custom server: llama.cpp's `llama-server` default.
    static let customServerDefaultURL = staticURL("http://localhost:8080")

    /// Stable identities of the built-in providers, shared by the factory
    /// that creates them and the views that show their status.
    static let ollamaID: ProviderID = "ollama"
    static let lmStudioID: ProviderID = "lmstudio"
    /// Logo image assets of the built-in providers (App/Resources/Assets.xcassets).
    static let ollamaLogo = "ProviderOllama"
    static let lmStudioLogo = "ProviderLMStudio"

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

    /// True when the URL designates this Mac. Anything else, including a
    /// machine on the local network, receives prompts and the file contents
    /// they quote, so the settings say so.
    static func isOnThisMac(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        if host == "localhost" || host.hasSuffix(".localhost") || host == "::1" || host == "[::1]" { return true }
        return host.hasPrefix("127.") && host.split(separator: ".").count == 4
    }

    /// For compile-time constant URLs only.
    private static func staticURL(_ string: String) -> URL {
        guard let url = URL(string: string) else { preconditionFailure("Invalid constant URL \(string)") }
        return url
    }
}

extension ProviderSettings {
    /// Decodes settings saved by any version of the `providers.v1` format;
    /// fields added later are optional.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ollama = try container.decode(Endpoint.self, forKey: .ollama)
        ollamaContextTokens = try container.decodeIfPresent(Int.self, forKey: .ollamaContextTokens)
        lmStudio = try container.decode(Endpoint.self, forKey: .lmStudio)
        idleTimeoutSeconds = try container.decode(Double.self, forKey: .idleTimeoutSeconds)
        customServers = try container.decodeIfPresent([CustomServer].self, forKey: .customServers) ?? []
    }
}
