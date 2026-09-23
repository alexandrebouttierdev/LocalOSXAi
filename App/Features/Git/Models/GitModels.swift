import Foundation

/// Working tree state of a repository.
struct GitStatus: Hashable, Sendable {
    /// `nil` when HEAD is detached.
    var branch: String?
    var upstream: String?
    var ahead = 0
    var behind = 0
    var files: [GitFileChange] = []

    var isClean: Bool { files.isEmpty }
}

/// One changed path, as `git status` reports it.
struct GitFileChange: Hashable, Sendable, Identifiable {
    enum Kind: String, Hashable, Sendable {
        case modified, added, deleted, renamed, copied, typeChanged, untracked, conflicted
    }

    let path: String
    /// Previous path for renames and copies.
    var originalPath: String?
    let kind: Kind
    /// True when the change is staged (in the index).
    let isStaged: Bool

    var id: String { path }

    /// One-letter code, as in `git status --short`.
    var code: String {
        switch kind {
        case .modified: "M"
        case .added: "A"
        case .deleted: "D"
        case .renamed: "R"
        case .copied: "C"
        case .typeChanged: "T"
        case .untracked: "?"
        case .conflicted: "U"
        }
    }
}

struct GitCommit: Hashable, Sendable, Identifiable {
    let hash: String
    let shortHash: String
    let author: String
    let date: Date?
    let subject: String

    var id: String { hash }
}

enum GitError: Error, Hashable, Sendable {
    case notARepository
    case commandFailed(code: Int32, message: String)
}

extension GitError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notARepository: "This project is not a Git repository."
        case let .commandFailed(code, message): "Git failed (exit \(code)): \(message)"
        }
    }
}
