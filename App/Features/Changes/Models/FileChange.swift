import Foundation

/// A file the agent changed, compared with its content before the first change.
struct FileChange: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case created, modified, deleted
    }

    let file: URL
    /// Relative to the project root.
    let path: String
    let status: Status
    let diff: FileDiff

    var id: URL { file }
}
