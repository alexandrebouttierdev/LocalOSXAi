import Foundation

/// The user's generation settings for one model, set in the inspector's
/// Model rows.
/// `nil` everywhere means “use the model's and provider's defaults”.
struct ModelSettings: Hashable, Sendable, Codable {
    /// 0 (focused) to 2 (creative).
    var temperature: Double?
    /// Only offered for models that reason.
    var reasoning: ReasoningEffort?
    /// Only offered when the provider can set the context length (Ollama);
    /// others fix it when the model is loaded.
    var contextTokens: Int?

    static let defaults = ModelSettings()
    static let temperatureRange = 0.0...2.0
    /// Temperatures offered in the inspector, from focused to varied.
    static let temperatureChoices = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.5, 2.0]
    static let contextChoices = [8_192, 16_384, 32_768, 65_536, 131_072]

    var isDefault: Bool { self == .defaults }

    /// Settings as provider options. The context is dropped when the provider
    /// cannot set it, so the budget never exceeds what is really allocated.
    func generationOptions(canSetContext: Bool) -> GenerationOptions {
        GenerationOptions(
            temperature: temperature.map { min(max($0, Self.temperatureRange.lowerBound), Self.temperatureRange.upperBound) },
            contextLength: canSetContext ? contextTokens : nil,
            reasoning: reasoning
        )
    }
}
