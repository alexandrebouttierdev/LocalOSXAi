import Foundation
import Synchronization
@testable import LocalOSXAi

/// A `ReleaseChecking` answering with a scripted release or error, and
/// counting how often it was asked.
final class StubReleaseChecker: ReleaseChecking {
    enum Outcome: Sendable {
        case release(AppRelease)
        case failure(any Error)
    }

    private let state: Mutex<(outcome: Outcome, calls: Int)>

    init(_ outcome: Outcome) {
        state = Mutex((outcome, 0))
    }

    /// Answers with a release of `version`.
    convenience init(latest version: String, notes: String = "") {
        self.init(.release(Self.release(version, notes: notes)))
    }

    var calls: Int { state.withLock { $0.calls } }

    func answer(_ outcome: Outcome) {
        state.withLock { $0.outcome = outcome }
    }

    func latestRelease() async throws -> AppRelease {
        let outcome = state.withLock { state in
            state.calls += 1
            return state.outcome
        }
        switch outcome {
        case .release(let release): return release
        case .failure(let error): throw error
        }
    }

    static func release(_ version: String, notes: String = "") -> AppRelease {
        guard let parsed = AppVersion(version),
              let page = URL(string: "https://github.com/alexandrebouttierdev/LocalOSXAi/releases/tag/v\(version)") else {
            preconditionFailure("Invalid test version \(version)")
        }
        return AppRelease(version: parsed, tag: "v\(version)", title: "LocalOSXAi v\(version)", notes: notes,
                          pageURL: page, publishedAt: nil)
    }
}
