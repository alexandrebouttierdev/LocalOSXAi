import Foundation
import Observation

/// Agent limits in Settings. Each change is saved at once: the values are
/// always valid (a stepper and a fixed list), so there is no draft to apply.
@MainActor
@Observable
final class AgentSettingsViewModel {
    private(set) var settings: AgentSettings
    var error: UserFacingError?
    /// What macOS allows, once read (`refreshNotificationPermission()`);
    /// `nil` without a notifier or before the first read.
    private(set) var notificationPermission: NotificationPermission?

    private let store: any AgentSettingsStore
    private let notifier: (any UserNotifying)?

    init(store: any AgentSettingsStore, notifier: (any UserNotifying)? = nil) {
        self.store = store
        self.notifier = notifier
        settings = store.load()
    }

    func setMaxIterations(_ value: Int) {
        update { $0.maxIterations = value }
    }

    func setToolTimeoutSeconds(_ value: Int) {
        update { $0.toolTimeoutSeconds = value }
    }

    func setSummarizesHistory(_ value: Bool) {
        update { $0.summarizesHistory = value }
    }

    func setCompactThresholdPercent(_ value: Int) {
        update { $0.compactThresholdPercent = value }
    }

    /// Turning notifications on asks macOS for permission if it never was.
    func setShowsNotifications(_ value: Bool) {
        update { $0.showsNotifications = value }
        if value { Task { await allowNotifications() } }
    }

    func refreshNotificationPermission() async {
        notificationPermission = await notifier?.permission()
    }

    /// Shows the macOS prompt if the user was never asked.
    func allowNotifications() async {
        notificationPermission = await notifier?.requestPermission()
    }

    func openNotificationSettings() {
        notifier?.openSystemSettings()
    }

    /// Posts a notification now, whatever the user is looking at, to check
    /// that macOS shows it (Focus, permission, banner style).
    func sendTestNotification() async {
        guard let notifier else { return }
        notificationPermission = await notifier.requestPermission()
        await notifier.post(UserNotification(
            sessionID: nil, title: "LocalOSXAi", subtitle: "Test notification",
            body: "Notifications work: you will be told when the agent answers or needs you.",
            playsSound: settings.playsSound
        ))
    }

    func setPlaysSound(_ value: Bool) {
        update { $0.playsSound = value }
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
