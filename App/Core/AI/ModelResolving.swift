import Foundation

/// A model together with the provider that serves it.
struct ResolvedModel: Sendable {
    let model: AIModel
    let provider: any LLMProvider
}

/// Finds the provider and current description of a model from its identity.
///
/// The agent receives only an `AIModel.ID` (what the user selected) and must
/// not know how providers are configured or discovered. Implemented by the
/// Models feature's `ProviderRegistry`, which owns discovery.
protocol ModelResolving: Sendable {
    /// Returns `nil` when the model is unknown or its provider is no longer
    /// configured (e.g. the user disabled it in Settings).
    func resolve(_ id: AIModel.ID) async -> ResolvedModel?
}
