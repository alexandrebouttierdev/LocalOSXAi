import Foundation
import Testing
@testable import LocalOSXAi

/// The update check as the workspace drives it: at launch, and from the
/// Check for Updates command.
@MainActor
@Suite("Workspace updates", .timeLimit(.minutes(1)))
struct WorkspaceUpdatesTests {
    private func makeWorkspace(checker: StubReleaseChecker?, checksAtLaunch: Bool = true) -> WorkspaceViewModel {
        var services = WorkspaceServices.stub()
        services.appInfo = AppInfo(infoDictionary: ["CFBundleShortVersionString": "0.0.0.1"])
        services.releaseChecker = checker
        services.checksForUpdatesAtLaunch = { checksAtLaunch }
        return WorkspaceViewModel(
            projects: ProjectsViewModel(service: ProjectService(repository: InMemoryProjectRepository())),
            sessions: SessionsViewModel(service: SessionService(repository: InMemorySessionRepository())),
            models: ModelsViewModel(registry: ProviderRegistry(providers: [])),
            services: services
        )
    }

    @Test("loading checks for updates in the background")
    func checksAtLaunch() async {
        let checker = StubReleaseChecker(latest: "0.0.0.2")
        let workspace = makeWorkspace(checker: checker)

        await workspace.load()
        await waitUntil { workspace.updates.showsBadge }

        #expect(workspace.updates.availableRelease?.tag == "v0.0.0.2")
        #expect(workspace.updates.currentVersion == AppVersion("0.0.0.1"))
        #expect(checker.calls == 1)
    }

    @Test("Check for Updates opens the update window, even with launch checks off")
    func checkCommand() async {
        let checker = StubReleaseChecker(latest: "0.0.0.1")
        let workspace = makeWorkspace(checker: checker, checksAtLaunch: false)
        await workspace.load()
        #expect(workspace.isEnabled(.checkForUpdates))

        workspace.perform(.checkForUpdates)
        await waitUntil { workspace.updates.status == .upToDate }

        #expect(workspace.updates.isSheetPresented)
        #expect(checker.calls == 1)
    }

    @Test("without a checker (simulated mode) the command is disabled with a reason")
    func simulated() {
        let workspace = makeWorkspace(checker: nil)
        #expect(workspace.disabledReason(for: .checkForUpdates) == "Update checks are off in simulated mode")
    }
}
