import Foundation

/// A model exposed by a provider, described only through abstract capabilities.
///
/// The agent runtime reasons about `capabilities` and `contextWindow`, never
/// about which provider serves the model. See docs/ai/model-capabilities.md.
struct AIModel: Identifiable, Hashable, Sendable, Codable {
    /// Globally unique model identity: the same model name can be served by
    /// several providers (e.g. `qwen3:8b` on Ollama and in LM Studio).
    struct ID: Hashable, Sendable, Codable {
        let provider: ProviderID
        /// The provider's own identifier, sent verbatim in requests (e.g. `gpt-oss:20b`).
        let name: String
    }

    let provider: ProviderID
    let name: String
    let displayName: String
    var contextWindow: ContextWindow
    var capabilities: ModelCapabilities

    var id: ID { ID(provider: provider, name: name) }

    var supportsTools: Bool { capabilities.contains(.tools) }
    var supportsVision: Bool { capabilities.contains(.vision) }
    var supportsStreaming: Bool { capabilities.contains(.streaming) }
    var supportsReasoning: Bool { capabilities.contains(.reasoning) }
}

/// Abstract features a model may support.
///
/// Capabilities are *declared* by providers and may be wrong (local runtimes
/// frequently advertise tool support for models that emit malformed calls).
/// The agent must still validate every tool call; see docs/ai/tools.md.
struct ModelCapabilities: OptionSet, Hashable, Sendable, Codable {
    let rawValue: Int

    static let tools = ModelCapabilities(rawValue: 1 << 0)
    static let vision = ModelCapabilities(rawValue: 1 << 1)
    static let streaming = ModelCapabilities(rawValue: 1 << 2)
    static let reasoning = ModelCapabilities(rawValue: 1 << 3)
}

/// The context size the application is willing to rely on for a model.
///
/// Invariant: `effective` never exceeds what the provider advertises, and is
/// never taken from the advertised value alone. Providers report a model's
/// theoretical maximum, not what the runtime was loaded with (Ollama silently
/// truncates to its `num_ctx`), so the application only relies on a size the
/// user configured, on the size the runtime reports as actually allocated,
/// or on a conservative fallback — in that order.
struct ContextWindow: Hashable, Sendable, Codable {
    /// Conservative size assumed when nothing more reliable is known.
    static let fallbackTokens = 8_192

    /// Maximum announced by the provider, if any. Only ever used as a cap.
    var advertisedTokens: Int?
    /// Size the runtime currently has allocated for the loaded model
    /// (LM Studio `loaded_context_length`, Ollama `/api/ps`). Reliable, but
    /// only known while the model is loaded.
    var loadedTokens: Int?
    /// Size explicitly configured by the user for this model.
    var configuredTokens: Int?
    /// The runtime allocates the context length sent with each request
    /// (Ollama's `num_ctx`), so the effective size is real even when it is the fallback.
    var allocatesRequestedTokens: Bool

    init(advertisedTokens: Int? = nil, loadedTokens: Int? = nil, configuredTokens: Int? = nil,
         allocatesRequestedTokens: Bool = false) {
        self.advertisedTokens = advertisedTokens
        self.loadedTokens = loadedTokens
        self.configuredTokens = configuredTokens
        self.allocatesRequestedTokens = allocatesRequestedTokens
    }

    /// False when the effective size is only the fallback guessed for a model
    /// that its runtime will load on demand with a size of its own (LM Studio
    /// after unloading an idle model): the model may get far more room.
    func isEffectiveSizeKnown(choosing chosen: Int?) -> Bool {
        allocatesRequestedTokens || chosen != nil || configuredTokens != nil || loadedTokens != nil
    }

    /// The token budget the context manager must respect, and the context
    /// length requested from runtimes that allocate on demand (Ollama).
    /// Reusing the loaded size avoids a costly model reload.
    /// The effective size when the user chose a context length for this run
    /// (per-model settings); `nil` keeps the usual rule.
    func effectiveTokens(choosing chosen: Int?) -> Int {
        var window = self
        if let chosen { window.configuredTokens = chosen }
        return window.effectiveTokens
    }

    var effectiveTokens: Int {
        let requested = configuredTokens ?? loadedTokens ?? Self.fallbackTokens
        guard let advertisedTokens, advertisedTokens > 0 else { return requested }
        return min(requested, advertisedTokens)
    }
}
