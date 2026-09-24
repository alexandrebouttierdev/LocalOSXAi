import Foundation

/// Storage port for per-model settings. Implemented in `Infrastructure/Persistence`.
protocol ModelSettingsRepository: Sendable {
    func allSettings() async throws -> [AIModel.ID: ModelSettings]
    /// Saves settings; saving the defaults removes the model's entry.
    func save(_ settings: ModelSettings, for model: AIModel.ID) async throws
}
