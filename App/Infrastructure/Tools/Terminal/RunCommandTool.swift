import Foundation

/// `run_command`: runs a shell command in the project folder.
///
/// Permission comes from `CommandPolicy` through the executor: read-only and
/// test commands run directly, others need approval, dangerous ones are
/// refused. The tool itself only runs what it was allowed to run.
struct RunCommandTool: AgentTool {
    static let commandTimeout: Duration = .seconds(120)

    let name = "run_command"
    let description = """
        Run a shell command in the project folder (zsh) and return its output and exit code. \
        Use it to build, run tests, or inspect the environment. Commands that change things \
        may need the user's approval; dangerous ones are refused.
        """
    let parameters = ToolParameterSchema(
        properties: ["command": .init(.string, "The command line to run, e.g. “swift test”.")],
        required: ["command"]
    )
    let effect = ToolEffect.executesCommands
    /// Slightly longer than the command timeout so the command's own
    /// timeout (which kills the process group) always fires first.
    var timeout: Duration? { Self.commandTimeout + .seconds(10) }

    let runner: any CommandRunner

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let command = try arguments.string("command")
        var output = ""
        var exit: CommandExit?
        do {
            for try await event in runner.run(.shell(command, in: context.projectRoot, timeout: Self.commandTimeout)) {
                switch event {
                case .output(let text, _): output += text
                case .exited(let status): exit = status
                }
            }
        } catch let error as TerminalError {
            throw ToolError.executionFailed(error.localizedDescription)
        }
        guard let exit else { throw ToolError.executionFailed("The command ended without an exit status.") }

        let seconds = String(format: "%.1f", Double(exit.duration.components.seconds) + Double(exit.duration.components.attoseconds) / 1e18)
        let status = exit.timedOut ? "timed out after \(Int(Self.commandTimeout.components.seconds)) s" : "exit code \(exit.code)"
        let trimmed = output.trimmingCharacters(in: .newlines)
        let body = "$ \(command)\n\(trimmed.isEmpty ? "(no output)" : trimmed)\n[\(status), \(seconds) s]"
        let summary = "Ran \(command.count > 60 ? String(command.prefix(57)) + "…" : command) — \(status)"
        return exit.succeeded ? .success(body, summary: summary) : .failure(body, summary: summary)
    }

    func describe(arguments: ToolArguments) -> String {
        "Run `\(arguments.values["command"]?.stringValue ?? "?")`"
    }
}
