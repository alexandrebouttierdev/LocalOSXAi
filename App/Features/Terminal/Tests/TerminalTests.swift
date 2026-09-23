import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("TerminalViewModel", .timeLimit(.minutes(1)))
struct TerminalViewModelTests {
    private let root = URL(fileURLWithPath: "/tmp/Demo")

    @Test("runs a command, streams its output and records the exit")
    func runsCommand() async throws {
        let exit = CommandExit(code: 0, duration: .milliseconds(120), timedOut: false)
        let runner = StubCommandRunner([.output("hello\n", .stdout), .output("warn\n", .stderr), .exited(exit)])
        let viewModel = TerminalViewModel(projectRoot: root, runner: runner)
        viewModel.input = "  echo hello  "

        viewModel.submit()
        await viewModel.waitUntilIdle()

        let entry = try #require(viewModel.entries.first)
        #expect(entry.command == "echo hello")
        #expect(entry.chunks == [.init(stream: .stdout, text: "hello\n"), .init(stream: .stderr, text: "warn\n")])
        #expect(entry.state == .finished(exit))
        #expect(runner.requests.first?.workingDirectory == root)
        #expect(viewModel.input.isEmpty)
        #expect(!viewModel.isRunning)
    }

    @Test("stopping marks the command as cancelled")
    func stop() async throws {
        let viewModel = TerminalViewModel(projectRoot: root, runner: StubCommandRunner([], hangs: true))
        viewModel.input = "sleep 100"
        viewModel.submit()
        #expect(viewModel.isRunning)

        viewModel.stop()
        await viewModel.waitUntilIdle()
        #expect(viewModel.entries.first?.state == .cancelled)
    }

    @Test("blocked commands need an explicit confirmation")
    func blockedNeedsConfirmation() async {
        let runner = StubCommandRunner()
        let viewModel = TerminalViewModel(projectRoot: root, runner: runner)
        viewModel.input = "rm -rf ~"
        viewModel.submit()

        #expect(viewModel.pendingConfirmation?.command == "rm -rf ~")
        #expect(runner.requests.isEmpty)

        viewModel.dismissPending()
        #expect(viewModel.pendingConfirmation == nil)
        #expect(runner.requests.isEmpty)
    }

    @Test("history is browsed with previous and next")
    func history() async {
        let viewModel = TerminalViewModel(projectRoot: root, runner: StubCommandRunner())
        for command in ["ls", "pwd"] {
            viewModel.input = command
            viewModel.submit()
            await viewModel.waitUntilIdle()
        }
        viewModel.previousCommand()
        #expect(viewModel.input == "pwd")
        viewModel.previousCommand()
        #expect(viewModel.input == "ls")
        viewModel.nextCommand()
        #expect(viewModel.input == "pwd")
        viewModel.nextCommand()
        #expect(viewModel.input.isEmpty)
    }

    @Test("clear keeps only running entries")
    func clear() async {
        let viewModel = TerminalViewModel(projectRoot: root, runner: StubCommandRunner())
        viewModel.input = "ls"
        viewModel.submit()
        await viewModel.waitUntilIdle()
        viewModel.clear()
        #expect(viewModel.entries.isEmpty)
    }
}

@Suite("TerminalEntry")
struct TerminalEntryTests {
    @Test("consecutive output of one stream is merged")
    func merging() {
        var entry = TerminalEntry(command: "x", startedAt: Date())
        entry.append("a", from: .stdout)
        entry.append("b", from: .stdout)
        entry.append("c", from: .stderr)
        #expect(entry.chunks == [.init(stream: .stdout, text: "ab"), .init(stream: .stderr, text: "c")])
    }

    @Test("output beyond the cap drops the oldest characters and says how many")
    func cap() {
        var entry = TerminalEntry(command: "x", startedAt: Date())
        entry.append(String(repeating: "a", count: TerminalEntry.maxOutputCharacters), from: .stdout)
        entry.append("tail", from: .stderr)
        #expect(entry.outputCharacters == TerminalEntry.maxOutputCharacters)
        #expect(entry.droppedCharacters == 4)
        #expect(entry.chunks.last?.text == "tail")
    }
}
