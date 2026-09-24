import Foundation

/// The content a file had before the agent first changed it.
struct TrackedOriginal: Hashable, Sendable {
    let file: URL
    let projectRoot: URL
    /// `nil` when the agent created the file.
    let content: Data?
}

/// Storage port for tracked originals, so changes can still be reviewed and
/// reverted after a relaunch. Implemented in `Infrastructure/Persistence`.
protocol ChangeOriginalsStore: Sendable {
    func allOriginals() async throws -> [TrackedOriginal]
    func save(_ original: TrackedOriginal) async throws
    func delete(file: URL) async throws
}
