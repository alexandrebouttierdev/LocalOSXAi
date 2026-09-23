import Foundation

/// `read_file`: returns a file's lines with line numbers.
struct ReadFileTool: AgentTool {
    static let defaultLineLimit = 400
    static let maxLineLimit = 2_000

    let name = "read_file"
    let description = """
        Read a UTF-8 text file from the project. Returns numbered lines. Use offset and limit \
        to read large files in parts.
        """
    let parameters = ToolParameterSchema(
        properties: [
            "path": .init(.string, "File path relative to the project root."),
            "offset": .init(.integer, "First line to return, starting at 1. Defaults to 1."),
            "limit": .init(.integer, "Maximum number of lines to return. Defaults to \(defaultLineLimit).")
        ],
        required: ["path"]
    )
    let effect = ToolEffect.readOnly

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let path = try arguments.string("path")
        let url = try ProjectBoundary.resolve(path, in: context.projectRoot)
        let relative = ProjectBoundary.relativePath(of: url, in: context.projectRoot)
        let offset = max(try arguments.optionalInt("offset") ?? 1, 1)
        let limit = min(max(try arguments.optionalInt("limit") ?? Self.defaultLineLimit, 1), Self.maxLineLimit)

        let text = try TextFileReader.read(url, relativePath: relative)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let lineCount = text.hasSuffix("\n") ? lines.count - 1 : lines.count
        guard lineCount > 0 else { return .success("(empty file)", summary: "Read \(relative) (empty)") }
        guard offset <= lineCount else {
            throw ToolError.invalidArgument(name: "offset", reason: "the file has only \(lineCount) lines")
        }

        let last = min(offset + limit - 1, lineCount)
        var output = (offset...last).map { number in
            "\(String(number).leftPadded(to: 6))\t\(lines[number - 1])"
        }.joined(separator: "\n")
        if last < lineCount {
            output += "\n… \(lineCount - last) more lines. Continue with offset \(last + 1)."
        }
        return .success(output, summary: "Read lines \(offset)–\(last) of \(relative)")
    }
}

/// `list_directory`: lists files and folders.
struct ListDirectoryTool: AgentTool {
    static let maxEntries = 500

    let name = "list_directory"
    let description = """
        List files and folders in a project directory. Folders end with “/”. Dependency, build \
        and hidden folders are skipped.
        """
    let parameters = ToolParameterSchema(
        properties: [
            "path": .init(.string, "Directory relative to the project root. Defaults to the root."),
            "recursive": .init(.boolean, "List subdirectories too. Defaults to false.")
        ]
    )
    let effect = ToolEffect.readOnly

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let url = try ProjectBoundary.resolve(try arguments.optionalString("path") ?? ".", in: context.projectRoot)
        let relative = ProjectBoundary.relativePath(of: url, in: context.projectRoot)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ToolError.executionFailed("“\(relative)” is not a directory.")
        }

        let walker = ProjectFileWalker(root: context.projectRoot)
        let result = try walker.entries(in: url, recursive: try arguments.optionalBool("recursive") ?? false, limit: Self.maxEntries)
        try Task.checkCancellation()
        guard !result.entries.isEmpty else { return .success("(empty directory)", summary: "Listed \(relative) (empty)") }

        var output = result.entries.map { $0.isDirectory ? $0.path + "/" : $0.path }.joined(separator: "\n")
        if result.truncated { output += "\n… more entries not shown (limit \(Self.maxEntries))." }
        let count = result.entries.count
        return .success(output, summary: "Listed \(count) \(count == 1 ? "entry" : "entries") in \(relative)")
    }
}

/// `search_files`: finds files whose path matches a glob pattern.
struct SearchFilesTool: AgentTool {
    static let maxResults = 200

    let name = "search_files"
    let description = """
        Find files by name or path pattern. Examples: “*.swift”, “**/Tests/*.swift”, \
        “*View*.{swift,md}”. Patterns without “/” match file names at any depth.
        """
    let parameters = ToolParameterSchema(
        properties: [
            "pattern": .init(.string, "Glob pattern."),
            "path": .init(.string, "Directory to search, relative to the project root. Defaults to the root.")
        ],
        required: ["pattern"]
    )
    let effect = ToolEffect.readOnly

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let pattern = try arguments.string("pattern")
        let matcher = GlobMatcher(pattern)
        guard matcher.isValid else { throw ToolError.invalidArgument(name: "pattern", reason: "not a valid glob pattern") }
        let directory = try ProjectBoundary.resolve(try arguments.optionalString("path") ?? ".", in: context.projectRoot)

        let walker = ProjectFileWalker(root: context.projectRoot)
        let files = try walker.files(in: directory, limit: 20_000).entries
        try Task.checkCancellation()
        let matches = files.filter { matcher.matches(path: $0.path) }
        guard !matches.isEmpty else { return .success("No files match “\(pattern)”.", summary: "No files match \(pattern)") }

        var output = matches.prefix(Self.maxResults).map(\.path).joined(separator: "\n")
        if matches.count > Self.maxResults { output += "\n… \(matches.count - Self.maxResults) more matches." }
        return .success(output, summary: "\(matches.count) file\(matches.count == 1 ? "" : "s") match \(pattern)")
    }
}

/// `search_text`: searches file contents.
struct SearchTextTool: AgentTool {
    static let maxMatches = 200
    static let maxLineLength = 300

    let name = "search_text"
    let description = """
        Search the contents of project files. Returns “path:line: text” for each match. Literal \
        and case-insensitive by default.
        """
    let parameters = ToolParameterSchema(
        properties: [
            "query": .init(.string, "Text or regular expression to find."),
            "is_regex": .init(.boolean, "Treat query as a regular expression. Defaults to false."),
            "case_sensitive": .init(.boolean, "Match case. Defaults to false."),
            "path": .init(.string, "Directory to search, relative to the project root. Defaults to the root."),
            "file_pattern": .init(.string, "Only search files matching this glob, e.g. “*.swift”.")
        ],
        required: ["query"]
    )
    let effect = ToolEffect.readOnly

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let query = try arguments.string("query")
        guard !query.isEmpty else { throw ToolError.invalidArgument(name: "query", reason: "must not be empty") }
        var options: NSRegularExpression.Options = (try arguments.optionalBool("case_sensitive") ?? false) ? [] : [.caseInsensitive]
        options.insert(.anchorsMatchLines)
        let pattern = (try arguments.optionalBool("is_regex") ?? false) ? query : NSRegularExpression.escapedPattern(for: query)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            throw ToolError.invalidArgument(name: "query", reason: "not a valid regular expression")
        }
        let filter = try arguments.optionalString("file_pattern").map { GlobMatcher($0) }
        let directory = try ProjectBoundary.resolve(try arguments.optionalString("path") ?? ".", in: context.projectRoot)

        let files = try ProjectFileWalker(root: context.projectRoot).files(in: directory, limit: 20_000).entries
        var matches: [String] = []
        var matchCount = 0
        for file in files where filter?.matches(path: file.path) ?? true {
            try Task.checkCancellation()
            // Secret-looking files are never searched: their contents would reach the model unasked.
            guard !ToolPermissionPolicy.isSensitive(path: file.path),
                  let text = try? TextFileReader.read(file.url, relativePath: file.path, maxBytes: 1_024 * 1_024) else { continue }
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let lineString = String(line)
                guard regex.firstMatch(in: lineString, range: NSRange(lineString.startIndex..., in: lineString)) != nil else { continue }
                matchCount += 1
                if matches.count < Self.maxMatches {
                    let excerpt = lineString.trimmingCharacters(in: .whitespaces).prefix(Self.maxLineLength)
                    matches.append("\(file.path):\(index + 1): \(excerpt)")
                }
            }
        }
        guard matchCount > 0 else { return .success("No matches for “\(query)”.", summary: "No matches for \(query)") }
        var output = matches.joined(separator: "\n")
        if matchCount > matches.count { output += "\n… \(matchCount - matches.count) more matches. Narrow the search." }
        return .success(output, summary: "\(matchCount) match\(matchCount == 1 ? "" : "es") for \(query)")
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
