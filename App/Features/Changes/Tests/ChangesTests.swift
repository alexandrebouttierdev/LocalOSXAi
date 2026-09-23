import Foundation
import Testing
@testable import LocalOSXAi

@Suite("FileDiff")
struct FileDiffTests {
    @Test("identical texts have no hunks")
    func identical() {
        let diff = FileDiff(old: "a\nb\n", new: "a\nb\n")
        #expect(diff.isEmpty)
        #expect(diff.addedLines == 0 && diff.removedLines == 0)
    }

    @Test("a changed line is a removal and an addition with line numbers")
    func changedLine() throws {
        let diff = FileDiff(old: "one\ntwo\nthree\n", new: "one\n2\nthree\n")
        #expect(diff.addedLines == 1)
        #expect(diff.removedLines == 1)
        let lines = try #require(diff.hunks.first).lines
        #expect(lines.contains(FileDiff.Line(kind: .removed, text: "two", oldNumber: 2, newNumber: nil)))
        #expect(lines.contains(FileDiff.Line(kind: .added, text: "2", oldNumber: nil, newNumber: 2)))
        #expect(diff.hunks.first?.header == "@@ -1,3 +1,3 @@")
    }

    @Test("distant changes make separate hunks with context")
    func hunks() {
        let old = (1...30).map { "line \($0)" }.joined(separator: "\n")
        var newLines = (1...30).map { "line \($0)" }
        newLines[1] = "changed 2"
        newLines[27] = "changed 28"
        let diff = FileDiff(old: old, new: newLines.joined(separator: "\n"))
        #expect(diff.hunks.count == 2)
        #expect(diff.hunks[0].lines.filter { $0.kind == .context }.count == 4)
    }

    @Test("a new file is all additions")
    func newFile() {
        let diff = FileDiff(old: "", new: "a\nb")
        #expect(diff.addedLines == 2)
        #expect(diff.removedLines == 0)
    }
}

@Suite("ChangeTracker")
struct ChangeTrackerTests {
    @Test("tracks modifications against the first original, and reverts exactly")
    func modifyAndRevert() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = try temp.makeFile("a.txt", contents: "original\n")
        let tracker = ChangeTracker()

        await tracker.willModify(file, in: temp.url)
        try Data("first edit\n".utf8).write(to: file)
        await tracker.willModify(file, in: temp.url)
        try Data("second edit\n".utf8).write(to: file)

        let changes = await tracker.changes(in: temp.url)
        #expect(changes.map(\.path) == ["a.txt"])
        #expect(changes.first?.status == .modified)
        #expect(changes.first?.diff.removedLines == 1)

        try await tracker.revert(file)
        #expect(try String(contentsOf: file, encoding: .utf8) == "original\n")
        #expect(await tracker.changes(in: temp.url).isEmpty)
    }

    @Test("reverting a created file deletes it; accepting forgets the change")
    func createdAndAccepted() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let tracker = ChangeTracker()
        let created = temp.url.appending(path: "new.txt")
        await tracker.willModify(created, in: temp.url)
        try Data("hi".utf8).write(to: created)
        let edited = try temp.makeFile("kept.txt", contents: "a")
        await tracker.willModify(edited, in: temp.url)
        try Data("b".utf8).write(to: edited)

        #expect(await tracker.changes(in: temp.url).map(\.status) == [.modified, .created])

        await tracker.accept(edited)
        try await tracker.revert(created)
        #expect(!FileManager.default.fileExists(atPath: created.path))
        #expect(try String(contentsOf: edited, encoding: .utf8) == "b")
        #expect(await tracker.changes(in: temp.url).isEmpty)
    }

    @Test("changes are scoped to their project, and revert all restores everything")
    func scopedAndRevertAll() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let projectA = try temp.makeDirectory("A")
        let projectB = try temp.makeDirectory("B")
        let fileA = try temp.makeFile("A/x.txt", contents: "1")
        let fileB = try temp.makeFile("B/y.txt", contents: "1")
        let tracker = ChangeTracker()
        for (file, root) in [(fileA, projectA), (fileB, projectB)] {
            await tracker.willModify(file, in: root)
            try Data("2".utf8).write(to: file)
        }

        #expect(await tracker.changes(in: projectA).map(\.path) == ["x.txt"])
        try await tracker.revertAll(in: projectA)
        #expect(try String(contentsOf: fileA, encoding: .utf8) == "1")
        #expect(await tracker.changes(in: projectB).count == 1)
    }

    @Test("a file edited back to its original is not a change")
    func noNetChange() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = try temp.makeFile("a.txt", contents: "same")
        let tracker = ChangeTracker()
        await tracker.willModify(file, in: temp.url)
        #expect(await tracker.changes(in: temp.url).isEmpty)
    }
}

@MainActor
@Suite("ChangesViewModel")
struct ChangesViewModelTests {
    @Test("lists changes with totals, then accept and revert update the list")
    func reviewFlow() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let tracker = ChangeTracker()
        let one = try temp.makeFile("one.txt", contents: "a\n")
        let two = try temp.makeFile("two.txt", contents: "b\n")
        for file in [one, two] {
            await tracker.willModify(file, in: temp.url)
            try Data("changed\nmore\n".utf8).write(to: file)
        }
        let viewModel = ChangesViewModel(projectRoot: temp.url, tracker: tracker)

        await viewModel.refresh()
        #expect(viewModel.changes.count == 2)
        #expect(viewModel.totals.added == 4)
        #expect(viewModel.selectedChange?.path == "one.txt")

        await viewModel.revert(try #require(viewModel.changes.first))
        #expect(try String(contentsOf: one, encoding: .utf8) == "a\n")
        await viewModel.acceptAll()
        #expect(viewModel.changes.isEmpty)
        #expect(try String(contentsOf: two, encoding: .utf8) == "changed\nmore\n")
    }
}

/// The executor's integration with previews and change recording.
@Suite("ToolExecutor with file changes", .timeLimit(.minutes(1)))
struct ToolExecutorChangeTests {
    @Test("an edit shows its diff before approval and is recorded for review")
    func previewAndRecord() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = try temp.makeFile("notes.md", contents: "# Notes\n- one\n")
        let tracker = ChangeTracker()
        let executor = ToolExecutor(registry: try ToolRegistry(FileSystemTools.all()))
        let approver = StubApprover(.allowOnce)

        let outcome = await executor.execute(
            Fixtures.call("edit_file", #"{"path":"notes.md","old_string":"- one","new_string":"- one\n- two"}"#),
            context: ToolContext(projectRoot: temp.url, changeRecorder: tracker), approver: approver
        ) { _ in }

        #expect(outcome.status == .succeeded)
        let preview = try #require(approver.requests.first?.preview)
        #expect(preview.path == "notes.md")
        #expect(!preview.isNewFile)
        #expect(preview.diff.addedLines == 1)
        #expect(await tracker.changes(in: temp.url).first?.diff.addedLines == 1)
        _ = file
    }

    @Test("an edit that cannot apply fails without asking the user")
    func impossibleEditSkipsApproval() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try temp.makeFile("a.txt", contents: "hello")
        let approver = StubApprover(.allowOnce)
        let outcome = await ToolExecutor(registry: try ToolRegistry(FileSystemTools.all())).execute(
            Fixtures.call("edit_file", #"{"path":"a.txt","old_string":"missing","new_string":"x"}"#),
            context: ToolContext(projectRoot: temp.url), approver: approver
        ) { _ in }

        #expect(outcome.status == .failed)
        #expect(approver.requests.isEmpty)
    }

    @Test("a denied write leaves nothing to review")
    func deniedWrite() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let tracker = ChangeTracker()
        _ = await ToolExecutor(registry: try ToolRegistry(FileSystemTools.all())).execute(
            Fixtures.call("write_file", #"{"path":"new.txt","content":"x"}"#),
            context: ToolContext(projectRoot: temp.url, changeRecorder: tracker), approver: StubApprover(.deny)
        ) { _ in }

        #expect(!FileManager.default.fileExists(atPath: temp.url.appending(path: "new.txt").path))
        #expect(await tracker.changes(in: temp.url).isEmpty)
    }
}
