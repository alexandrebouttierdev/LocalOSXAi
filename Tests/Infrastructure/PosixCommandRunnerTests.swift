import Foundation
import Testing
@testable import LocalOSXAi

/// Runs real processes: these are integration tests of the process layer.
@Suite("PosixCommandRunner", .timeLimit(.minutes(1)))
struct PosixCommandRunnerTests {
    private let runner = PosixCommandRunner()
    private let directory = FileManager.default.temporaryDirectory

    @Test("captures stdout, stderr and the exit code")
    func successAndStreams() async throws {
        let result = try await runner.collect(.shell("echo hello; echo oops >&2", in: directory))
        #expect(result.output == "hello\n")
        #expect(result.stderr == "oops\n")
        #expect(result.exit.code == 0)
        #expect(result.exit.succeeded)
    }

    @Test("a failing command reports its exit code")
    func failure() async throws {
        let result = try await runner.collect(.shell("exit 3", in: directory))
        #expect(result.exit.code == 3)
        #expect(!result.exit.succeeded)
    }

    @Test("runs in the requested working directory")
    func workingDirectory() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let result = try await runner.collect(.shell("pwd", in: temp.url))
        #expect(URL(fileURLWithPath: result.output.trimmingCharacters(in: .newlines)).lastPathComponent == temp.url.lastPathComponent)
    }

    @Test("a timeout stops the command")
    func timeout() async throws {
        let start = ContinuousClock.now
        let result = try await runner.collect(.shell("sleep 30", in: directory, timeout: .milliseconds(300)))
        #expect(result.exit.timedOut)
        #expect(!result.exit.succeeded)
        #expect(ContinuousClock.now - start < .seconds(10))
    }

    @Test("cancellation kills the command and its children")
    func cancellation() async throws {
        let marker = "31.\(Int.random(in: 100_000...999_999))"
        let stream = runner.run(.shell("sleep \(marker) & sleep \(marker); wait", in: directory))
        let consumer = Task { try await { for try await _ in stream {} }() }
        try await Task.sleep(for: .milliseconds(500))
        consumer.cancel()
        _ = await consumer.result

        var alive = true
        for _ in 0..<50 where alive {
            try await Task.sleep(for: .milliseconds(100))
            alive = try await runner.collect(.shell("pgrep -f 'sleep \(marker)' || true", in: directory))
                .output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        #expect(!alive)
    }

    @Test("secret-looking environment variables are not passed on")
    func scrubsEnvironment() {
        let scrubbed = PosixCommandRunner.scrubbedEnvironment(["PATH": "/bin", "OPENAI_API_KEY": "x", "GITHUB_TOKEN": "y",
                                                               "DB_PASSWORD": "z", "HOME": "/Users/x"])
        #expect(Set(scrubbed.keys) == ["PATH", "HOME"])
    }

    @Test("multi-byte characters are never split")
    func utf8() async throws {
        let result = try await runner.collect(.shell("printf 'é🚀ü%.0s' $(seq 1 3000)", in: directory))
        #expect(result.output.count == 9_000)
        #expect(!result.output.contains("\u{FFFD}"))
    }

    @Test("runs executables directly without a shell")
    func executable() async throws {
        let request = CommandRequest(invocation: .executable(path: "/bin/echo", arguments: ["a b", "$HOME"]), workingDirectory: directory)
        #expect(try await runner.collect(request).output == "a b $HOME\n")
    }

    @Test("UTF-8 boundary detection")
    func boundary() {
        let rocket = Data("🚀".utf8)
        #expect(UTF8Boundary.completePrefixLength(of: Data("ab".utf8)) == 2)
        #expect(UTF8Boundary.completePrefixLength(of: Data("a".utf8) + rocket.prefix(2)) == 1)
        #expect(UTF8Boundary.completePrefixLength(of: Data("a".utf8) + rocket) == 5)
    }
}
