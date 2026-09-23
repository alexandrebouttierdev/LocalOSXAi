import Foundation

/// Remembers the original content of every file the agent changes, so the
/// user can review the diff and revert.
///
/// The original is captured once, before the *first* change in the app's
/// lifetime (or since the change was last accepted), so several edits to the
/// same file review and revert as one. Contents are kept as raw bytes: a
/// revert restores exactly what was there.
actor ChangeTracker: FileChangeRecording {
    private struct Entry {
        let projectRoot: URL
        /// `nil` when the file did not exist.
        let original: Data?
    }

    private var entries: [URL: Entry] = [:]

    func willModify(_ file: URL, in projectRoot: URL) {
        guard entries[file] == nil else { return }
        entries[file] = Entry(projectRoot: projectRoot, original: FileManager.default.contents(atPath: file.path))
    }

    func didModify(_ file: URL, in projectRoot: URL) {}

    /// Files changed in a project, with their diff. Files whose content went
    /// back to the original are not listed.
    func changes(in projectRoot: URL) -> [FileChange] {
        entries.compactMap { file, entry -> FileChange? in
            guard entry.projectRoot == projectRoot else { return nil }
            let current = FileManager.default.contents(atPath: file.path)
            guard current != entry.original else { return nil }
            let status: FileChange.Status = entry.original == nil ? .created : (current == nil ? .deleted : .modified)
            let diff = FileDiff(old: Self.text(entry.original), new: Self.text(current))
            return FileChange(file: file, path: ProjectBoundary.relativePath(of: file, in: projectRoot), status: status, diff: diff)
        }
        .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Content shown in the diff. Binary content is summarized rather than
    /// rendered as garbage.
    private static func text(_ data: Data?) -> String {
        guard let data else { return "" }
        return String(bytes: data, encoding: .utf8) ?? "(binary content, \(data.count) bytes)"
    }

    /// Keeps the current content and stops tracking the file.
    func accept(_ file: URL) {
        entries[file] = nil
    }

    /// Restores the original content (or removes a created file).
    func revert(_ file: URL) throws {
        guard let entry = entries[file] else { return }
        if let original = entry.original {
            try original.write(to: file, options: .atomic)
        } else if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        entries[file] = nil
    }

    func acceptAll(in projectRoot: URL) {
        entries = entries.filter { $0.value.projectRoot != projectRoot }
    }

    /// Reverts every change in the project; stops at the first failure.
    func revertAll(in projectRoot: URL) throws {
        for (file, entry) in entries where entry.projectRoot == projectRoot {
            try revert(file)
        }
    }
}
