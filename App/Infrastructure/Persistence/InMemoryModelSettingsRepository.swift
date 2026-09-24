import Foundation

/// Process-lifetime model settings, for simulated mode and tests.
actor InMemoryModelSettingsRepository: ModelSettingsRepository {
    private var settings: [AIModel.ID: ModelSettings]

    init(settings: [AIModel.ID: ModelSettings] = [:]) {
        self.settings = settings
    }

    func allSettings() -> [AIModel.ID: ModelSettings] {
        settings
    }

    func save(_ newValue: ModelSettings, for model: AIModel.ID) {
        settings[model] = newValue.isDefault ? nil : newValue
    }
}
