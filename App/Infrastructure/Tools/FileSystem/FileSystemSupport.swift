import Foundation

/// Reads project files as text, refusing what a model should not receive.
enum TextFileReader {
    /// Files larger than this are refused (read_file) or skipped (search).
    static let maxBytes = 2 * 1_024 * 1_024

    /// - Throws: `ToolError.executionFailed` for missing files, folders,
    ///   binaries, oversized or non-UTF-8 files, and permission errors.
    static func read(_ url: URL, relativePath: String, maxBytes: Int = maxBytes) throws(ToolError) -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw .executionFailed("No file at “\(relativePath)”.")
        }
        guard !isDirectory.boolValue else {
            throw .executionFailed("“\(relativePath)” is a folder. Use list_directory instead.")
        }
        let data: Data
        do {
            let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
            guard size <= maxBytes else {
                throw ToolError.executionFailed(
                    "“\(relativePath)” is too large (\(size / 1_024) KB). Use search_text to find the relevant part."
                )
            }
            data = try Data(contentsOf: url)
        } catch let error as ToolError {
            throw error
        } catch {
            throw .executionFailed("Cannot read “\(relativePath)”: \(error.localizedDescription)")
        }
        guard !isBinary(data) else { throw .executionFailed("“\(relativePath)” is a binary file.") }
        guard let text = String(bytes: data, encoding: .utf8) else {
            throw .executionFailed("“\(relativePath)” is not UTF-8 text.")
        }
        return text
    }

    /// A NUL byte in the first 8 KB is a reliable, cheap binary indicator.
    static func isBinary(_ data: Data) -> Bool {
        data.prefix(8_192).contains(0)
    }
}

/// Enumerates project files, skipping folders that are never useful to a
/// coding agent (dependencies, build products, VCS internals) and hidden
/// files, which often hold local configuration or secrets.
struct ProjectFileWalker: Sendable {
    static let ignoredDirectoryNames: Set<String> = [
        ".git", ".hg", ".svn", ".build", ".swiftpm", "DerivedData", "build", "Pods", "Carthage",
        "node_modules", "dist", ".next", ".nuxt", ".venv", "venv", "__pycache__", ".idea", ".gradle", "target"
    ]

    struct Entry: Hashable, Sendable {
        let url: URL
        /// Relative to the project root.
        let path: String
        let isDirectory: Bool
    }

    let root: URL

    /// Entries under `directory`, sorted by path.
    ///
    /// - Parameters:
    ///   - recursive: descend into subfolders (ignored folders excluded).
    ///   - limit: maximum number of entries; `truncated` reports whether more existed.
    func entries(in directory: URL, recursive: Bool, limit: Int) throws(ToolError) -> (entries: [Entry], truncated: Bool) {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        if !recursive { options.insert(.skipsSubdirectoryDescendants) }
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys, options: options) else {
            throw .executionFailed("Cannot list “\(ProjectBoundary.relativePath(of: directory, in: root))”.")
        }

        var entries: [Entry] = []
        var truncated = false
        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory, Self.ignoredDirectoryNames.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard entries.count < limit else {
                truncated = true
                break
            }
            entries.append(Entry(url: url, path: ProjectBoundary.relativePath(of: url, in: root), isDirectory: isDirectory))
        }
        return (entries.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }, truncated)
    }

    /// Regular files under `directory`, recursively.
    func files(in directory: URL, limit: Int) throws(ToolError) -> (entries: [Entry], truncated: Bool) {
        let result = try entries(in: directory, recursive: true, limit: limit * 4)
        let files = result.entries.filter { !$0.isDirectory }
        return (Array(files.prefix(limit)), result.truncated || files.count > limit)
    }
}

/// Glob patterns for file paths: `*` (within a path segment), `**` (across
/// segments), `?`, and `{a,b}` alternatives. A pattern without `/` matches
/// the file name only, so `*.swift` finds Swift files at any depth.
struct GlobMatcher: Sendable {
    private let regex: NSRegularExpression?
    private let matchesNameOnly: Bool

    init(_ pattern: String) {
        matchesNameOnly = !pattern.contains("/")
        regex = try? NSRegularExpression(pattern: "^" + Self.translate(pattern) + "$", options: [.caseInsensitive])
    }

    var isValid: Bool { regex != nil }

    func matches(path: String) -> Bool {
        guard let regex else { return false }
        let subject = matchesNameOnly ? (path as NSString).lastPathComponent : path
        return regex.firstMatch(in: subject, range: NSRange(subject.startIndex..., in: subject)) != nil
    }

    private static func translate(_ pattern: String) -> String {
        var result = ""
        var characters = Array(pattern)[...]
        while let character = characters.popFirst() {
            switch character {
            case "*" where characters.first == "*":
                characters.removeFirst()
                if characters.first == "/" {
                    characters.removeFirst()
                    result += "(?:.*/)?"
                } else {
                    result += ".*"
                }
            case "*": result += "[^/]*"
            case "?": result += "[^/]"
            case "{": result += "(?:"
            case "}": result += ")"
            case ",": result += "|"
            default: result += NSRegularExpression.escapedPattern(for: String(character))
            }
        }
        return result
    }
}
