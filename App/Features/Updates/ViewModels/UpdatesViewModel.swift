import Foundation
import Observation

/// Checks whether a newer version of the app was released: once at launch,
/// quietly, and whenever the user asks.
///
/// A check at launch never interrupts: a newer version shows as a badge in
/// the sidebar, and a failure is only logged. A check the user asked for
/// opens the update window with its result, including failures.
@MainActor
@Observable
final class UpdatesViewModel {
    /// The running app's version; `nil` when its Info.plist has none, and
    /// then nothing is ever reported as newer.
    let currentVersion: AppVersion?
    private(set) var status: UpdateStatus = .idle
    /// The update window.
    var isSheetPresented = false
    /// “Later” hides the sidebar badge until the next launch.
    private(set) var isDismissed = false

    private let checker: (any ReleaseChecking)?
    private let checksAtLaunch: @Sendable () -> Bool
    private var hasCheckedAtLaunch = false

    /// - Parameters:
    ///   - checker: `nil` turns update checks off (simulated mode).
    ///   - checksAtLaunch: read at launch, so the Settings choice applies.
    init(currentVersion: String, checker: (any ReleaseChecking)?, checksAtLaunch: @escaping @Sendable () -> Bool) {
        self.currentVersion = AppVersion(currentVersion)
        self.checker = checker
        self.checksAtLaunch = checksAtLaunch
    }

    /// False when this build cannot check (simulated mode).
    var canCheck: Bool { checker != nil }

    var isChecking: Bool { status == .checking }

    var availableRelease: AppRelease? {
        if case .available(let release) = status { release } else { nil }
    }

    /// A newer version the user has not put off with “Later”.
    var showsBadge: Bool { availableRelease != nil && !isDismissed }

    /// At most once per launch, and only if Settings allows it.
    func checkAtLaunch() async {
        guard !hasCheckedAtLaunch else { return }
        hasCheckedAtLaunch = true
        guard checksAtLaunch() else { return }
        await check(reportsFailure: false)
    }

    /// Opens the update window and checks, whatever the Settings choice.
    func checkNow() async {
        isSheetPresented = true
        await check(reportsFailure: true)
    }

    /// Opens the update window on the version already found.
    func showAvailableUpdate() {
        isSheetPresented = true
    }

    /// Closes the window and hides the badge until the next launch.
    func later() {
        isDismissed = true
        isSheetPresented = false
    }

    func close() {
        isSheetPresented = false
    }

    private func check(reportsFailure: Bool) async {
        guard let checker, !isChecking else { return }
        let previous = status
        status = .checking
        do {
            let release = try await checker.latestRelease()
            if let currentVersion, release.version > currentVersion {
                status = .available(release)
                isDismissed = false
            } else {
                status = .upToDate
            }
        } catch is CancellationError {
            status = previous
        } catch UpdateCheckError.noRelease {
            // Nothing published yet, so nothing newer than this build.
            status = .upToDate
        } catch {
            let failure = UserFacingError(error, title: "Could not check for updates", category: .updates)
            status = reportsFailure ? .failed(failure) : previous
        }
    }
}
