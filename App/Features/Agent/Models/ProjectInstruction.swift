import Foundation

/// Instructions a project gives to agents (its `AGENTS.md`).
struct ProjectInstruction: Hashable, Sendable {
    /// Path relative to the project root, shown to the user and the model.
    let source: String
    let content: String
    /// True when the file exceeded the size cap and was cut.
    let isTruncated: Bool
}
