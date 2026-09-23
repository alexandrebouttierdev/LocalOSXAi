import Foundation

/// `GitService` backed by the `git` command-line tool.
///
/// Git runs directly (no shell), so paths never need quoting, with
/// `GIT_OPTIONAL_LOCKS=0` semantics via `--no-optional-locks` so reading
/// status never contends with the user's own Git operations.
struct CLIGitService: GitService {
    static let gitPath = "/usr/bin/git"
    static let timeout: Duration = .seconds(20)

    let runner: any CommandRunner

    func status(in root: URL) async throws -> GitStatus {
        GitOutputParser.status(porcelainV2: try await git(["status", "--porcelain=v2", "--branch", "-z"], in: root))
    }

    func diff(in root: URL, path: String?, staged: Bool) async throws -> String {
        var arguments = ["diff", "--no-color", "--no-ext-diff"]
        if staged { arguments.append("--cached") }
        if let path { arguments += ["--", path] }
        return try await git(arguments, in: root)
    }

    func log(in root: URL, limit: Int) async throws -> [GitCommit] {
        do {
            let arguments = ["log", "-n", String(max(limit, 1)), "--no-color", "--pretty=format:\(GitOutputParser.logFormat)"]
            let output = try await git(arguments, in: root)
            return GitOutputParser.log(output)
        } catch GitError.commandFailed(_, let message) where message.contains("does not have any commits") {
            return []
        }
    }

    private func git(_ arguments: [String], in root: URL) async throws -> String {
        let request = CommandRequest(
            invocation: .executable(path: Self.gitPath, arguments: ["--no-optional-locks", "-C", root.path] + arguments),
            workingDirectory: root,
            timeout: Self.timeout
        )
        let result = try await runner.collect(request)
        guard result.exit.succeeded else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.contains("not a git repository") { throw GitError.notARepository }
            throw GitError.commandFailed(code: result.exit.code, message: message)
        }
        return result.output
    }
}
