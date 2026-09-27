import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("Agent settings")
struct AgentSettingsTests {
    /// A store whose saves fail, for the error path.
    private final class FailingStore: AgentSettingsStore {
        struct Failure: Error {}
        func load() -> AgentSettings { .defaults }
        func save(_ settings: AgentSettings) throws { throw Failure() }
    }

    @Test("out-of-range values are brought back in range")
    func clamping() {
        #expect(AgentSettings(maxIterations: 1, toolTimeoutSeconds: 31).clamped == AgentSettings(maxIterations: 5, toolTimeoutSeconds: 30))
        #expect(AgentSettings(maxIterations: 900, toolTimeoutSeconds: 10_000).clamped.maxIterations == 100)
        #expect(AgentSettings(maxIterations: 900, toolTimeoutSeconds: 10_000).clamped.toolTimeoutSeconds == 300)
        #expect(AgentSettings.defaults.clamped == .defaults)
    }

    @Test("changes are saved at once and clamped")
    func savesChanges() {
        let store = InMemoryAgentSettingsStore()
        let viewModel = AgentSettingsViewModel(store: store)

        viewModel.setMaxIterations(40)
        viewModel.setToolTimeoutSeconds(120)
        #expect(store.load() == AgentSettings(maxIterations: 40, toolTimeoutSeconds: 120))

        viewModel.setMaxIterations(1_000)
        #expect(viewModel.settings.maxIterations == AgentSettings.maxIterationsRange.upperBound)

        viewModel.resetToDefaults()
        #expect(store.load() == .defaults)
    }

    @Test("summarizing history is on by default, can be turned off, and survives clamping")
    func summarizesHistory() {
        let store = InMemoryAgentSettingsStore()
        let viewModel = AgentSettingsViewModel(store: store)
        #expect(viewModel.settings.summarizesHistory)

        viewModel.setSummarizesHistory(false)

        #expect(!store.load().summarizesHistory)
        #expect(!store.load().clamped.summarizesHistory)
        #expect(!AppEnvironment.agentLimits(from: store.load()).summarizesHistory)
    }

    @Test("settings saved before the summary option existed turn it on")
    func legacySettings() throws {
        let json = #"{"maxIterations":40,"toolTimeoutSeconds":60}"#
        let settings = try JSONDecoder().decode(AgentSettings.self, from: Data(json.utf8))
        #expect(settings == AgentSettings(maxIterations: 40, toolTimeoutSeconds: 60, summarizesHistory: true))
        #expect(settings.compactThresholdPercent == 50)
        #expect(settings.showsNotifications)
        #expect(settings.playsSound)
    }

    @Test("notifications and sound are on by default, saved when changed and passed to the workspace")
    func notificationChoices() {
        let store = InMemoryAgentSettingsStore()
        let viewModel = AgentSettingsViewModel(store: store)
        #expect(AppEnvironment.notificationPreferences(from: store.load()) == NotificationPreferences())

        viewModel.setShowsNotifications(false)
        viewModel.setPlaysSound(false)

        #expect(AppEnvironment.notificationPreferences(from: store.load())
                == NotificationPreferences(showsNotifications: false, playsSound: false))
        #expect(store.load().clamped == store.load())
    }

    @Test("the summary threshold is saved, kept to its choices and becomes the runtime's start ratio")
    func compactThreshold() {
        let store = InMemoryAgentSettingsStore()
        let viewModel = AgentSettingsViewModel(store: store)
        #expect(viewModel.settings.compactThresholdPercent == 50)

        viewModel.setCompactThresholdPercent(70)
        #expect(store.load().compactThresholdPercent == 70)
        #expect(AppEnvironment.agentLimits(from: store.load()).summaryStartRatio == 0.7)

        viewModel.setCompactThresholdPercent(99)
        #expect(viewModel.settings.compactThresholdPercent == 80)
        viewModel.setCompactThresholdPercent(5)
        #expect(viewModel.settings.compactThresholdPercent == 30)
    }

    @Test("a failed save keeps the previous value and reports an error")
    func failedSave() {
        let viewModel = AgentSettingsViewModel(store: FailingStore())
        viewModel.setMaxIterations(50)
        #expect(viewModel.settings == .defaults)
        #expect(viewModel.error != nil)
    }

    @Test("UserDefaults round-trips settings and ignores unreadable data")
    func userDefaultsStore() throws {
        let suite = "LocalOSXAiTests.agent.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let store = UserDefaultsAgentSettingsStore(suiteName: suite)
        #expect(store.load() == .defaults)

        try store.save(AgentSettings(maxIterations: 60, toolTimeoutSeconds: 60))
        #expect(store.load() == AgentSettings(maxIterations: 60, toolTimeoutSeconds: 60))

        UserDefaults(suiteName: suite)?.set(Data("oops".utf8), forKey: UserDefaultsAgentSettingsStore.key)
        #expect(store.load() == .defaults)
    }

    @Test("settings map to the runtime's limits")
    func limitsMapping() {
        let limits = AppEnvironment.agentLimits(from: AgentSettings(maxIterations: 40, toolTimeoutSeconds: 60))
        #expect(limits.maxIterations == 40)
        #expect(limits.toolTimeout == .seconds(60))
        #expect(limits.summaryStartRatio == HistoryCompaction.defaultStartRatio)
    }
}

@MainActor
@Suite("Notification settings", .timeLimit(.minutes(1)))
struct NotificationSettingsTests {
    @Test("the macOS permission is read, asked for, and a test notification is posted")
    func permissionAndTest() async throws {
        let notifier = RecordingNotifier()
        let viewModel = AgentSettingsViewModel(store: InMemoryAgentSettingsStore(), notifier: notifier)
        #expect(viewModel.notificationPermission == nil)

        await viewModel.refreshNotificationPermission()
        #expect(viewModel.notificationPermission == .notDetermined)
        await viewModel.allowNotifications()
        #expect(viewModel.notificationPermission == .allowed)

        await viewModel.sendTestNotification()
        let test = try #require(notifier.posted.last)
        #expect(test.sessionID == nil)
        #expect(test.playsSound)

        viewModel.openNotificationSettings()
        #expect(notifier.openedSystemSettings)
    }

    @Test("a denied permission is shown as such, and turning notifications on asks again only if never asked")
    func denied() async {
        let notifier = RecordingNotifier()
        notifier.answer = .denied
        let store = InMemoryAgentSettingsStore()
        let viewModel = AgentSettingsViewModel(store: store, notifier: notifier)
        viewModel.setShowsNotifications(false)
        viewModel.setShowsNotifications(true)
        for _ in 0..<100 where viewModel.notificationPermission == nil { await Task.yield() }

        #expect(viewModel.notificationPermission == .denied)
        #expect(notifier.permissionRequests == 1)
    }
}
