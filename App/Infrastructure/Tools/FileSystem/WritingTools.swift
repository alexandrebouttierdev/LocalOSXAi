import Foundation

/// `write_file`: creates or replaces a file.
struct WriteFileTool: AgentTool {
    let name = "write_file"
    let description = """
        Create a file, or replace a file's entire content. Parent folders are created. Prefer \
        edit_file to change part of an existing file.
        """
    let parameters = ToolParameterSchema(
        properties: [
            "path": .init(.string, "File path relative to the project root."),
            "content": .init(.string, "The complete new content of the file.")
        ],
        required: ["path", "content"]
    )
    let effect = ToolEffect.writesFiles

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let url = try ProjectBoundary.resolve(try arguments.string("path"), in: context.projectRoot)
        let relative = ProjectBoundary.relativePath(of: url, in: context.projectRoot)
        let content = try arguments.string("content")

        var isDirectory: ObjCBool = false
        let existed = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard !isDirectory.boolValue else { throw ToolError.executionFailed("“\(relative)” is a folder.") }
        try Task.checkCancellation()
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url, options: .atomic)
        } catch {
            throw ToolError.executionFailed("Cannot write “\(relative)”: \(error.localizedDescription)")
        }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).count
        let verb = existed ? "Replaced" : "Created"
        return .success("\(verb) \(relative) (\(lines) lines).", summary: "\(verb) \(relative)")
    }

    func describe(arguments: ToolArguments) -> String {
        let path = arguments.values["path"]?.stringValue ?? "?"
        let lines = arguments.values["content"]?.stringValue?.split(separator: "\n", omittingEmptySubsequences: false).count ?? 0
        return "Write \(path) (\(lines) lines)"
    }

    func proposedChange(arguments: ToolArguments, context: ToolContext) async throws -> ProposedFileChange? {
        let url = try ProjectBoundary.resolve(try arguments.string("path"), in: context.projectRoot)
        let relative = ProjectBoundary.relativePath(of: url, in: context.projectRoot)
        let current = FileManager.default.fileExists(atPath: url.path) ? try? TextFileReader.read(url, relativePath: relative) : nil
        return ProposedFileChange(file: url, path: relative, currentContent: current, proposedContent: try arguments.string("content"))
    }
}

/// `edit_file`: replaces an exact text fragment.
///
/// Requiring a unique exact match (unless `replace_all`) makes edits
/// predictable: an ambiguous fragment fails instead of changing the wrong place.
struct EditFileTool: AgentTool {
    let name = "edit_file"
    let description = """
        Replace an exact fragment of a file. old_string must match the file exactly (including \
        indentation) and be unique, unless replace_all is true. Read the file first.
        """
    let parameters = ToolParameterSchema(
        properties: [
            "path": .init(.string, "File path relative to the project root."),
            "old_string": .init(.string, "Exact text to replace."),
            "new_string": .init(.string, "Replacement text."),
            "replace_all": .init(.boolean, "Replace every occurrence. Defaults to false.")
        ],
        required: ["path", "old_string", "new_string"]
    )
    let effect = ToolEffect.writesFiles

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let edit = try computeEdit(arguments: arguments, context: context)
        try Task.checkCancellation()
        do {
            try Data(edit.updated.utf8).write(to: edit.url, options: .atomic)
        } catch {
            throw ToolError.executionFailed("Cannot write “\(edit.relative)”: \(error.localizedDescription)")
        }
        return .success("Edited \(edit.relative): \(edit.count) replacement\(edit.count == 1 ? "" : "s").",
                        summary: "Edited \(edit.relative)")
    }

    func proposedChange(arguments: ToolArguments, context: ToolContext) async throws -> ProposedFileChange? {
        let edit = try computeEdit(arguments: arguments, context: context)
        return ProposedFileChange(file: edit.url, path: edit.relative, currentContent: edit.original, proposedContent: edit.updated)
    }

    private struct Edit {
        let url: URL
        let relative: String
        let original: String
        let updated: String
        let count: Int
    }

    /// Validates the edit and computes the new content without writing.
    private func computeEdit(arguments: ToolArguments, context: ToolContext) throws -> Edit {
        let url = try ProjectBoundary.resolve(try arguments.string("path"), in: context.projectRoot)
        let relative = ProjectBoundary.relativePath(of: url, in: context.projectRoot)
        let oldString = try arguments.string("old_string")
        let newString = try arguments.string("new_string")
        let replaceAll = try arguments.optionalBool("replace_all") ?? false
        guard !oldString.isEmpty else {
            throw ToolError.invalidArgument(name: "old_string", reason: "must not be empty; use write_file to create a file")
        }
        guard oldString != newString else { throw ToolError.invalidArgument(name: "new_string", reason: "is identical to old_string") }

        let text = try TextFileReader.read(url, relativePath: relative)
        let occurrences = text.components(separatedBy: oldString).count - 1
        guard occurrences > 0 else {
            throw ToolError.executionFailed("old_string was not found in “\(relative)”. Read the file and copy the text exactly.")
        }
        guard occurrences == 1 || replaceAll else {
            throw ToolError.executionFailed(
                "old_string appears \(occurrences) times in “\(relative)”. Add surrounding lines to make it unique, or set replace_all."
            )
        }
        let updated: String
        if replaceAll {
            updated = text.replacingOccurrences(of: oldString, with: newString)
        } else if let range = text.range(of: oldString) {
            updated = text.replacingCharacters(in: range, with: newString)
        } else {
            updated = text
        }
        return Edit(url: url, relative: relative, original: text, updated: updated, count: replaceAll ? occurrences : 1)
    }

    func describe(arguments: ToolArguments) -> String {
        let path = arguments.values["path"]?.stringValue ?? "?"
        let replaceAll = arguments.values["replace_all"]?.boolValue == true
        return "Edit \(path)" + (replaceAll ? " (all occurrences)" : "")
    }
}

/// The built-in filesystem tools, in the order they are offered to models.
enum FileSystemTools {
    static func all() -> [any AgentTool] {
        [ReadFileTool(), ListDirectoryTool(), SearchFilesTool(), SearchTextTool(), EditFileTool(), WriteFileTool()]
    }
}
