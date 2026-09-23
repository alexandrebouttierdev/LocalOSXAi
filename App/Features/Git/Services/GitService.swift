import Foundation

/// Read access to a Git repository. Implemented in `Infrastructure/Git`.
///
/// Only read operations exist for now. Operations that change the repository
/// (commit, checkout, stash) will require confirmation, and remote ones
/// (push, pull) always will (docs/security/command-execution.md).
protocol GitService: Sendable {
    func status(in root: URL) async throws -> GitStatus
    /// Unified diff of the working tree (or of the index when `staged`), for one path or all.
    func diff(in root: URL, path: String?, staged: Bool) async throws -> String
    func log(in root: URL, limit: Int) async throws -> [GitCommit]
}

/// Parsers for Git's machine-readable output. Pure, so they are tested on
/// fixtures without running Git.
enum GitOutputParser {
    /// Parses `git status --porcelain=v2 --branch -z`.
    static func status(porcelainV2 output: String) -> GitStatus {
        var status = GitStatus()
        var fields = output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)[...]
        while let field = fields.popFirst() {
            if field.hasPrefix("# ") {
                header(field, into: &status)
                continue
            }
            let parts = field.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
            switch parts.first {
            case "1" where parts.count >= 9:
                status.files += changes(xy: parts[1], path: parts[8...].joined(separator: " "), original: nil)
            case "2" where parts.count >= 10:
                // For renames and copies the original path is the next NUL-separated field.
                let original = fields.popFirst()
                status.files += changes(xy: parts[1], path: parts[9...].joined(separator: " "), original: original)
            case "u" where parts.count >= 11:
                status.files.append(GitFileChange(path: parts[10...].joined(separator: " "), kind: .conflicted, isStaged: false))
            case "?" where parts.count >= 2:
                status.files.append(GitFileChange(path: parts[1...].joined(separator: " "), kind: .untracked, isStaged: false))
            default:
                continue
            }
        }
        return status
    }

    private static func header(_ field: String, into status: inout GitStatus) {
        let parts = field.split(separator: " ").map(String.init)
        guard parts.count >= 3 else { return }
        switch parts[1] {
        case "branch.head": status.branch = parts[2] == "(detached)" ? nil : parts[2]
        case "branch.upstream": status.upstream = parts[2]
        case "branch.ab" where parts.count >= 4:
            status.ahead = Int(parts[2].dropFirst()) ?? 0
            status.behind = Int(parts[3].dropFirst()) ?? 0
        default: break
        }
    }

    /// An `XY` code yields up to two entries: the staged (X) and unstaged (Y) change.
    private static func changes(xy: String, path: String, original: String?) -> [GitFileChange] {
        let codes = Array(xy)
        guard codes.count == 2 else { return [] }
        return zip([true, false], codes).compactMap { isStaged, code in
            kind(for: code).map { GitFileChange(path: path, originalPath: original, kind: $0, isStaged: isStaged) }
        }
    }

    private static func kind(for code: Character) -> GitFileChange.Kind? {
        switch code {
        case "M": .modified
        case "A": .added
        case "D": .deleted
        case "R": .renamed
        case "C": .copied
        case "T": .typeChanged
        case "U": .conflicted
        default: nil
        }
    }

    static let fieldSeparator = "\u{1F}"
    static let recordSeparator = "\u{1E}"
    /// `--pretty` format matching `log(_:)`.
    static let logFormat = "%H%x1f%h%x1f%an%x1f%aI%x1f%s%x1e"

    /// Parses `git log --pretty=format:<logFormat>`.
    static func log(_ output: String) -> [GitCommit] {
        let dates = ISO8601DateFormatter()
        return output.components(separatedBy: recordSeparator).compactMap { record in
            let fields = record.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: fieldSeparator)
            guard fields.count == 5 else { return nil }
            return GitCommit(hash: fields[0], shortHash: fields[1], author: fields[2],
                             date: dates.date(from: fields[3]), subject: fields[4])
        }
    }
}
