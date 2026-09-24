import Foundation

/// Storage port for agent settings. Implemented in `Infrastructure/Settings`.
protocol AgentSettingsStore: Sendable {
    /// Returns the saved settings (clamped), or `AgentSettings.defaults` when
    /// nothing was saved or the saved data cannot be read.
    func load() -> AgentSettings
    func save(_ settings: AgentSettings) throws
}
