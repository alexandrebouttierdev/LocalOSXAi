import Foundation
import Testing
@testable import LocalOSXAi

@Suite("run_command", .timeLimit(.minutes(1)))
struct RunCommandToolTests {
    private let tool = RunCommandTool(runner: PosixCommandRunner())

    private func run(_ command: String, in root: URL) async throws -> ToolResult {
        try await tool.execute(arguments: ToolArguments(["command": .string(command)]), context: ToolContext(projectRoot: root))
    }

    @Test("a successful command returns its output and exit code")
    func success() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try temp.makeFile("a.txt", contents: "x")
        let result = try await run("ls", in: temp.url)
        #expect(result.status == .success)
        #expect(result.output.hasPrefix("$ ls\na.txt\n[exit code 0,"))
        #expect(result.summary == "Ran ls — exit code 0")
    }

    @Test("a failing command is a failed result with its output")
    func failure() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let result = try await run("echo broken >&2; exit 2", in: temp.url)
        #expect(result.status == .failure)
        #expect(result.output.contains("broken"))
        #expect(result.output.contains("exit code 2"))
    }

    @Test("the executor applies the command policy to the tool")
    func policyThroughExecutor() async throws {
        let executor = ToolExecutor(registry: try ToolRegistry([tool]))
        let context = ToolContext(projectRoot: FileManager.default.temporaryDirectory)

        let allowed = await executor.execute(Fixtures.call("run_command", #"{"command":"echo ok"}"#), context: context,
                                             approver: StubApprover(.deny)) { _ in }
        #expect(allowed.status == .succeeded)

        let approver = StubApprover(.deny)
        let asked = await executor.execute(Fixtures.call("run_command", #"{"command":"npm install"}"#), context: context,
                                           approver: approver) { _ in }
        #expect(asked.status == .denied)
        #expect(approver.requests.first?.summary == "Run `npm install`")

        let blocked = await executor.execute(Fixtures.call("run_command", #"{"command":"sudo rm -rf /"}"#), context: context,
                                             approver: StubApprover(.allowOnce)) { _ in }
        #expect(blocked.status == .denied)
        #expect(blocked.output.hasPrefix("Blocked by policy"))
    }
}
