import Foundation
import Testing
@testable import LocalOSXAi

/// Notifications and sounds when a session needs the user.
@MainActor
@Suite("Workspace notifications", .timeLimit(.minutes(1)))
struct WorkspaceNotificationTests {
    private let project = Fixtures.project()

    private func makeWorkspace(sessions: [Session], notifier: RecordingNotifier,
                               preferences: NotificationPreferences = NotificationPreferences(),
                               projects: [Project]? = nil) -> WorkspaceViewModel {
        var services = WorkspaceServices.stub(agent: StubAgentService(.events([
            .assistantMessageStarted(id: UUID()), .textDelta("Fixed."), .finished(.completed)
        ])))
        services.notifier = notifier
        services.notificationPreferences = { preferences }
        return WorkspaceViewModel(
            projects: ProjectsViewModel(service: ProjectService(repository: InMemoryProjectRepository(projects: projects ?? [project]))),
            sessions: SessionsViewModel(service: SessionService(repository: InMemorySessionRepository(sessions: sessions))),
            models: ModelsViewModel(registry: ProviderRegistry(providers: [
                MockLLMProvider(id: "fake", displayName: "Fake", models: .success([Fixtures.model("m", capabilities: [.tools])]))
            ])),
            services: services
        )
    }

    private func send(in workspace: WorkspaceViewModel) async throws {
        let agent = try #require(workspace.activeAgent)
        agent.draft = "Fix it"
        agent.send()
        await agent.waitUntilIdle()
        // The post is started in a task.
        await Task.yield()
    }

    @Test("an answer in the background posts a notification for the session")
    func background() async throws {
        let session = Fixtures.session(projectID: project.id, title: "Login bug")
        let notifier = RecordingNotifier()
        let workspace = makeWorkspace(sessions: [session], notifier: notifier)
        await workspace.load()
        workspace.isAppActive = false

        try await send(in: workspace)
        for _ in 0..<100 where notifier.posted.isEmpty { await Task.yield() }

        #expect(notifier.posted == [UserNotification(sessionID: session.id, title: "Login bug", subtitle: project.name,
                                                     body: "Fixed.", playsSound: true)])
        #expect(notifier.soundCount == 0)
    }

    @Test("an answer the user is looking at only plays the sound, if chosen")
    func visible() async throws {
        let session = Fixtures.session(projectID: project.id)
        let notifier = RecordingNotifier()
        let workspace = makeWorkspace(sessions: [session], notifier: notifier)
        await workspace.load()
        #expect(workspace.isVisible(session.id))

        try await send(in: workspace)
        #expect(notifier.posted.isEmpty)
        #expect(notifier.soundCount == 1)

        let quiet = RecordingNotifier()
        let silent = makeWorkspace(sessions: [session], notifier: quiet,
                                   preferences: NotificationPreferences(showsNotifications: true, playsSound: false))
        await silent.load()
        try await send(in: silent)
        #expect(quiet.soundCount == 0)
        #expect(quiet.posted.isEmpty)
    }

    @Test("another tab or the settings screen counts as not looking")
    func otherView() async {
        let session = Fixtures.session(projectID: project.id)
        let workspace = makeWorkspace(sessions: [session], notifier: RecordingNotifier())
        await workspace.load()

        workspace.perform(.showFiles)
        #expect(!workspace.isVisible(session.id))
        workspace.perform(.showAgent)
        workspace.showSettings()
        #expect(!workspace.isVisible(session.id))
    }

    @Test("clicking a notification opens its session, even in another project and from the settings")
    func click() async {
        let other = Fixtures.project(name: "Other", root: URL(fileURLWithPath: "/tmp/Other"))
        let target = Fixtures.session(projectID: other.id, title: "Elsewhere")
        let current = Fixtures.session(projectID: project.id, title: "Here")
        let notifier = RecordingNotifier()
        let workspace = makeWorkspace(sessions: [target, current], notifier: notifier, projects: [project, other])
        await workspace.load()
        await workspace.selectProject(project.id)
        workspace.perform(.showChanges)
        workspace.showSettings()

        notifier.click(target.id)
        for _ in 0..<200 where workspace.selectedSessionID != target.id { await Task.yield() }

        #expect(workspace.selectedProjectID == other.id)
        #expect(workspace.selectedSessionID == target.id)
        #expect(workspace.selectedTab == .agent)
        #expect(!workspace.isSettingsPresented)
    }
}
