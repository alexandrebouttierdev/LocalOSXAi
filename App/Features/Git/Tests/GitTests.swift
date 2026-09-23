import Foundation
import Testing
@testable import LocalOSXAi

@Suite("GitOutputParser")
struct GitOutputParserTests {
    @Test("parses branch headers and every entry type of porcelain v2")
    func status() {
        let output = [
            "# branch.oid 1234abcd", "# branch.head main", "# branch.upstream origin/main", "# branch.ab +2 -1",
            "1 .M N... 100644 100644 100644 aaa bbb Sources/App.swift",
            "1 A. N... 000000 100644 100644 000 ccc README with spaces.md",
            "2 R. N... 100644 100644 100644 ddd eee R100 New.swift", "Old.swift",
            "u UU N... 100644 100644 100644 100644 f1 f2 f3 Conflict.swift",
            "? notes.txt"
        ].joined(separator: "\0") + "\0"
        let status = GitOutputParser.status(porcelainV2: output)

        #expect(status.branch == "main")
        #expect(status.upstream == "origin/main")
        #expect(status.ahead == 2 && status.behind == 1)
        #expect(status.files == [
            GitFileChange(path: "Sources/App.swift", kind: .modified, isStaged: false),
            GitFileChange(path: "README with spaces.md", kind: .added, isStaged: true),
            GitFileChange(path: "New.swift", originalPath: "Old.swift", kind: .renamed, isStaged: true),
            GitFileChange(path: "Conflict.swift", kind: .conflicted, isStaged: false),
            GitFileChange(path: "notes.txt", kind: .untracked, isStaged: false)
        ])
    }

    @Test("a detached HEAD has no branch; a clean tree has no files")
    func detachedAndClean() {
        let status = GitOutputParser.status(porcelainV2: "# branch.oid abc\0# branch.head (detached)\0")
        #expect(status.branch == nil)
        #expect(status.isClean)
    }

    @Test("parses the log format")
    func log() {
        let output = ["abc123", "abc", "Ada", "2026-09-20T10:00:00+02:00", "Fix: a | b"].joined(separator: GitOutputParser.fieldSeparator)
            + GitOutputParser.recordSeparator + "\n"
        let commits = GitOutputParser.log(output)
        #expect(commits.count == 1)
        #expect(commits.first?.subject == "Fix: a | b")
        #expect(commits.first?.date != nil)
    }
}

/// `CLIGitService` against real temporary repositories.
@Suite("CLIGitService", .timeLimit(.minutes(1)))
struct CLIGitServiceTests {
    private let runner = PosixCommandRunner()
    private var git: CLIGitService { CLIGitService(runner: runner) }

    private func repository() async throws -> TemporaryDirectory {
        let temp = try TemporaryDirectory()
        let setup = "git init -q -b main && git config user.email t@example.com && git config user.name Test"
            + " && echo one > a.txt && git add a.txt && git commit -q -m 'First commit'"
        let result = try await runner.collect(.shell(setup, in: temp.url))
        #expect(result.exit.succeeded, "\(result.stderr)")
        return temp
    }

    @Test("status, diff and log of a real repository")
    func realRepository() async throws {
        let temp = try await repository()
        defer { temp.remove() }
        try temp.makeFile("a.txt", contents: "two\n")
        try temp.makeFile("b.txt", contents: "new\n")

        let status = try await git.status(in: temp.url)
        #expect(status.branch == "main")
        #expect(Set(status.files.map(\.path)) == ["a.txt", "b.txt"])

        let diff = try await git.diff(in: temp.url, path: "a.txt", staged: false)
        #expect(diff.contains("-one"))
        #expect(diff.contains("+two"))

        let log = try await git.log(in: temp.url, limit: 5)
        #expect(log.map(\.subject) == ["First commit"])
    }

    @Test("a folder outside Git reports notARepository")
    func notARepository() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        await #expect(throws: GitError.notARepository) { try await git.status(in: temp.url) }
    }

    @Test("git tools format status and log for the model")
    func tools() async throws {
        let temp = try await repository()
        defer { temp.remove() }
        try temp.makeFile("a.txt", contents: "changed\n")
        let context = ToolContext(projectRoot: temp.url)

        let status = try await GitStatusTool(git: git).execute(arguments: ToolArguments(), context: context)
        #expect(status.output.contains("Branch: main"))
        #expect(status.output.contains("unstaged M a.txt"))

        let log = try await GitLogTool(git: git).execute(arguments: ToolArguments(["limit": 1]), context: context)
        #expect(log.output.contains("Test: First commit"))

        await #expect(throws: ToolError.self) {
            try await GitDiffTool(git: git).execute(arguments: ToolArguments(["path": "../outside"]), context: context)
        }
    }
}

@MainActor
@Suite("GitViewModel")
struct GitViewModelTests {
    @Test("loads status and last commit, or reports a non-repository")
    func states() async {
        let commit = GitCommit(hash: "h", shortHash: "h", author: "A", date: nil, subject: "Init")
        let loaded = GitViewModel(projectRoot: URL(fileURLWithPath: "/tmp"), git: StubGitService(commits: [commit]))
        await loaded.refresh()
        #expect(loaded.state == .loaded(GitStatus(branch: "main"), lastCommit: commit))

        let plain = GitViewModel(projectRoot: URL(fileURLWithPath: "/tmp"), git: StubGitService(error: .notARepository))
        await plain.refresh()
        #expect(plain.state == .notARepository)
    }
}
