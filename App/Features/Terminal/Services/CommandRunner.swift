import Foundation

/// What to run and where.
struct CommandRequest: Hashable, Sendable {
    enum Invocation: Hashable, Sendable {
        /// A command line interpreted by the user's login shell (PATH, aliases-free).
        case shell(String)
        /// A program run directly with arguments, with no shell parsing (used for Git).
        case executable(path: String, arguments: [String])
    }

    let invocation: Invocation
    let workingDirectory: URL
    /// Stops the command (and its children) after this delay. `nil`: no limit.
    var timeout: Duration?

    static func shell(_ command: String, in directory: URL, timeout: Duration? = nil) -> CommandRequest {
        CommandRequest(invocation: .shell(command), workingDirectory: directory, timeout: timeout)
    }
}

enum CommandOutputStream: String, Hashable, Sendable, Codable {
    case stdout
    case stderr
}

/// How a command ended.
struct CommandExit: Hashable, Sendable {
    /// Exit code, or 128 + signal number when killed by a signal (shell convention).
    let code: Int32
    let duration: Duration
    let timedOut: Bool

    var succeeded: Bool { code == 0 && !timedOut }
}

enum CommandEvent: Hashable, Sendable {
    case output(String, CommandOutputStream)
    case exited(CommandExit)
}

/// Runs processes and streams their output.
///
/// Contract: output arrives as it is produced; `.exited` is the last event;
/// cancelling the consumer terminates the whole process group (the command
/// and everything it started), then the stream throws `CancellationError`.
protocol CommandRunner: Sendable {
    func run(_ request: CommandRequest) -> AsyncThrowingStream<CommandEvent, Error>
}

enum TerminalError: Error, Hashable, Sendable {
    case launchFailed(String)
}

extension TerminalError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .launchFailed(let reason): "The command could not be started: \(reason)"
        }
    }
}

/// The collected result of a command run to completion.
struct CommandResult: Hashable, Sendable {
    var output = ""
    var stderr = ""
    var exit = CommandExit(code: -1, duration: .zero, timedOut: false)
}

extension CommandRunner {
    /// Runs a command to completion and returns its output streams and exit.
    func collect(_ request: CommandRequest) async throws -> CommandResult {
        var result = CommandResult()
        for try await event in run(request) {
            switch event {
            case .output(let text, .stdout): result.output += text
            case .output(let text, .stderr): result.stderr += text
            case .exited(let status): result.exit = status
            }
        }
        return result
    }
}
