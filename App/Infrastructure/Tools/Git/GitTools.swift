import Foundation

/// `git_status`: branch and changed files.
struct GitStatusTool: AgentTool {
    let name = "git_status"
    let description = "Show the current branch, its upstream, and changed files (staged, unstaged, untracked)."
    let parameters = ToolParameterSchema.empty
    let effect = ToolEffect.readOnly
    let git: any GitService

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let status = try await git.status(in: context.projectRoot)
        var lines = ["Branch: \(status.branch ?? "(detached HEAD)")"]
        if let upstream = status.upstream {
            lines.append("Upstream: \(upstream) (ahead \(status.ahead), behind \(status.behind))")
        }
        if status.isClean {
            lines.append("Working tree clean.")
        } else {
            lines += status.files.map { "\($0.isStaged ? "staged  " : "unstaged") \($0.code) \($0.path)" }
        }
        return .success(lines.joined(separator: "\n"), summary: status.isClean ? "Working tree clean" : "\(status.files.count) changes")
    }
}

/// `git_diff`: unified diff of uncommitted changes.
struct GitDiffTool: AgentTool {
    let name = "git_diff"
    let description = "Show the unified diff of uncommitted changes, for one file or the whole project."
    let parameters = ToolParameterSchema(
        properties: [
            "path": .init(.string, "Limit the diff to this file, relative to the project root."),
            "staged": .init(.boolean, "Show staged changes instead of unstaged ones. Defaults to false.")
        ]
    )
    let effect = ToolEffect.readOnly
    let git: any GitService

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let path = try arguments.optionalString("path")
        if let path { _ = try ProjectBoundary.resolve(path, in: context.projectRoot) }
        let diff = try await git.diff(in: context.projectRoot, path: path, staged: try arguments.optionalBool("staged") ?? false)
        guard !diff.isEmpty else { return .success("No changes.", summary: "No changes") }
        return .success(diff, summary: "Diff of \(path ?? "all files")")
    }
}

/// `git_log`: recent commits.
struct GitLogTool: AgentTool {
    let name = "git_log"
    let description = "Show recent commits: short hash, date, author and subject."
    let parameters = ToolParameterSchema(properties: ["limit": .init(.integer, "Number of commits, 1–50. Defaults to 10.")])
    let effect = ToolEffect.readOnly
    let git: any GitService

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let limit = min(max(try arguments.optionalInt("limit") ?? 10, 1), 50)
        let commits = try await git.log(in: context.projectRoot, limit: limit)
        guard !commits.isEmpty else { return .success("No commits yet.", summary: "No commits") }
        let dates = ISO8601DateFormatter()
        let lines = commits.map { "\($0.shortHash) \($0.date.map { dates.string(from: $0) } ?? "?") \($0.author): \($0.subject)" }
        return .success(lines.joined(separator: "\n"), summary: "\(commits.count) recent commits")
    }
}
