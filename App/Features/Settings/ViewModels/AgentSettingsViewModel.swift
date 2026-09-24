import Foundation
import Observation

/// Agent limits in Settings. Each change is saved at once: the values are
/// always valid (a stepper and a fixed list), so there is no draft to apply.
@MainActor
@Observable
final class AgentSettingsViewModel {
    private(set) var settings: AgentSettings
    var error: UserFacingError?

    private let store: any AgentSettingsStore

    init(store: any AgentSettingsStore) {
        self.store = store
        settings = store.load()
    }

    func setMaxIterations(_ value: Int) {
        update { $0.maxIterations = value }
    }

    func setToolTimeoutSeconds(_ value: Int) {
        update { $0.toolTimeoutSeconds = value }
    }

    func resetToDefaults() {
        update { $0 = .defaults }
    }

    private func update(_ change: (inout AgentSettings) -> Void) {
        var next = settings
        change(&next)
        next = next.clamped
        guard next != settings else { return }
        do {
            try store.save(next)
            settings = next
        } catch {
            self.error = UserFacingError(error, title: "Could not save agent settings", category: .persistence)
        }
    }
}
