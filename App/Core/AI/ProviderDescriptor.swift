import Foundation

/// Stable identifier of a configured provider instance.
///
/// It is a string rather than an enum so several endpoints of the same kind
/// (for example two OpenAI-compatible servers) can coexist, and so new
/// providers never require changes to the agent runtime.
struct ProviderID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { self.rawValue = value }

    var description: String { rawValue }
}

/// User-visible identity of a provider.
///
/// Only the UI and configuration layers read this. The agent runtime must not
/// branch on it: see docs/ai/providers.md, "Provider agnosticism".
struct ProviderDescriptor: Hashable, Sendable, Identifiable {
    let id: ProviderID
    /// Human-readable name shown next to model names, e.g. "Ollama" or "LM Studio".
    let displayName: String
    /// Base URL of the server, when the provider is network-backed.
    let endpoint: URL?
}
