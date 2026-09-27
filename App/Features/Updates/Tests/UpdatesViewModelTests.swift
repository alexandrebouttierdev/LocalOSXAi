import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("UpdatesViewModel", .timeLimit(.minutes(1)))
struct UpdatesViewModelTests {
    private func makeViewModel(current: String = "0.0.0.1", checker: StubReleaseChecker?,
                               checksAtLaunch: Bool = true) -> UpdatesViewModel {
        UpdatesViewModel(currentVersion: current, checker: checker, checksAtLaunch: { checksAtLaunch })
    }

    @Test("a newer release found at launch shows the badge, without opening the window")
    func newerAtLaunch() async {
        let checker = StubReleaseChecker(latest: "0.0.0.2", notes: "## What's new")
        let viewModel = makeViewModel(checker: checker)

        await viewModel.checkAtLaunch()

        #expect(viewModel.availableRelease?.tag == "v0.0.0.2")
        #expect(viewModel.showsBadge)
        #expect(!viewModel.isSheetPresented)
    }

    @Test("the same or an older release is up to date", arguments: ["0.0.0.1", "0.0.0.1.0", "0.0.0.0.9"])
    func upToDate(latest: String) async {
        let viewModel = makeViewModel(checker: StubReleaseChecker(latest: latest))
        await viewModel.checkAtLaunch()
        #expect(viewModel.status == .upToDate)
        #expect(!viewModel.showsBadge)
    }

    @Test("the launch check runs once, and not at all when Settings turns it off")
    func launchCheckOnce() async {
        let checker = StubReleaseChecker(latest: "0.0.0.2")
        let viewModel = makeViewModel(checker: checker)
        await viewModel.checkAtLaunch()
        await viewModel.checkAtLaunch()
        #expect(checker.calls == 1)

        let off = StubReleaseChecker(latest: "0.0.0.2")
        let disabled = makeViewModel(checker: off, checksAtLaunch: false)
        await disabled.checkAtLaunch()
        #expect(off.calls == 0)
        #expect(disabled.status == .idle)
    }

    @Test("a failure at launch stays silent")
    func silentLaunchFailure() async {
        let viewModel = makeViewModel(checker: StubReleaseChecker(.failure(UpdateCheckError.unreachable)))
        await viewModel.checkAtLaunch()
        #expect(viewModel.status == .idle)
        #expect(!viewModel.isSheetPresented)
    }

    @Test("checking now opens the window and reports a failure with its reason")
    func manualFailure() async throws {
        let checker = StubReleaseChecker(.failure(UpdateCheckError.rateLimited))
        let viewModel = makeViewModel(checker: checker, checksAtLaunch: false)

        await viewModel.checkNow()

        #expect(viewModel.isSheetPresented)
        guard case .failed(let error) = viewModel.status else {
            Issue.record("Expected a failure, got \(viewModel.status)")
            return
        }
        #expect(error.title == "Could not check for updates")
        #expect(error.message == UpdateCheckError.rateLimited.errorDescription)

        checker.answer(.release(StubReleaseChecker.release("0.0.0.3")))
        await viewModel.checkNow()
        #expect(viewModel.availableRelease?.version == AppVersion("0.0.0.3"))
    }

    @Test("with nothing published yet, the app is up to date")
    func noRelease() async {
        let viewModel = makeViewModel(checker: StubReleaseChecker(.failure(UpdateCheckError.noRelease)))
        await viewModel.checkNow()
        #expect(viewModel.status == .upToDate)
    }

    @Test("a cancelled check keeps the previous result")
    func cancellation() async {
        let checker = StubReleaseChecker(latest: "0.0.0.2")
        let viewModel = makeViewModel(checker: checker)
        await viewModel.checkAtLaunch()

        checker.answer(.failure(CancellationError()))
        await viewModel.checkNow()

        #expect(viewModel.availableRelease?.tag == "v0.0.0.2")
    }

    @Test("Later hides the badge and closes the window; a new check shows it again")
    func later() async {
        let checker = StubReleaseChecker(latest: "0.0.0.2")
        let viewModel = makeViewModel(checker: checker)
        await viewModel.checkAtLaunch()
        viewModel.showAvailableUpdate()
        #expect(viewModel.isSheetPresented)

        viewModel.later()

        #expect(!viewModel.isSheetPresented)
        #expect(!viewModel.showsBadge)
        #expect(viewModel.availableRelease != nil)

        await viewModel.checkNow()
        #expect(viewModel.showsBadge)
    }

    @Test("without a checker or a readable version, nothing is reported")
    func unavailable() async {
        let viewModel = makeViewModel(checker: nil)
        #expect(!viewModel.canCheck)
        await viewModel.checkNow()
        #expect(viewModel.status == .idle)

        let unknown = makeViewModel(current: "—", checker: StubReleaseChecker(latest: "9.9"))
        await unknown.checkAtLaunch()
        #expect(unknown.status == .upToDate)
    }
}
