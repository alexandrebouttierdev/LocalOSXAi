import Foundation

/// Finds the latest published release of the app. Implemented in
/// `Infrastructure/Updates`; tests use a stub.
protocol ReleaseChecking: Sendable {
    /// The latest full release (never a draft or a pre-release).
    ///
    /// Throws `UpdateCheckError`, or `CancellationError` when the task is
    /// cancelled.
    func latestRelease() async throws -> AppRelease
}
