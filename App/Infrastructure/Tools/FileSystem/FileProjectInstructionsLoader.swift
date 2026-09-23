import Foundation

/// Loads `AGENTS.md` from the project root.
///
/// Only `AGENTS.md` is loaded: other conventions (`CLAUDE.md`,
/// `.cursor/rules`) are opt-in per project once project settings exist
/// (Phase 5), so rules from different systems are never mixed silently
/// (docs/ai/context.md, “Project instructions”).
struct FileProjectInstructionsLoader: ProjectInstructionsLoading {
    static let fileNames = ["AGENTS.md"]
    /// Instructions beyond this size are cut, and the cut is reported.
    static let maxCharacters = 16_000

    func instructions(for projectRoot: URL) async -> [ProjectInstruction] {
        Self.fileNames.compactMap { name in
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
