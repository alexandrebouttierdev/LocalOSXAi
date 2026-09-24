import Foundation

/// Loads `AGENTS.md` from the project root, then `CLAUDE.md` when the
/// project opted in.
///
/// `CLAUDE.md` is opt-in per project so rules from different systems are
/// never mixed silently; it comes after `AGENTS.md`, labelled with its
/// source (docs/ai/context.md, “Project instructions”).
struct FileProjectInstructionsLoader: ProjectInstructionsLoading {
    static let primaryFileName = "AGENTS.md"
    static let claudeFileName = "CLAUDE.md"
    /// Instructions beyond this size are cut, and the cut is reported.
    static let maxCharacters = 16_000

    func instructions(for projectRoot: URL, includingClaudeInstructions: Bool) async -> [ProjectInstruction] {
        let names = includingClaudeInstructions ? [Self.primaryFileName, Self.claudeFileName] : [Self.primaryFileName]
        return names.compactMap { name in
            let url = projectRoot.appending(path: name)
            guard let text = try? TextFileReader.read(url, relativePath: name, maxBytes: 256 * 1_024) else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let isTruncated = trimmed.count > Self.maxCharacters
            return ProjectInstruction(
                source: name,
                content: isTruncated ? String(trimmed.prefix(Self.maxCharacters)) : trimmed,
                isTruncated: isTruncated
            )
        }
    }
}
