import Foundation
import OSLog

/// Remembers the original content of every file the agent changes, so the
/// user can review the diff and revert.
///
/// The original is captured once, before the *first* change (or since the
/// change was last accepted), so several edits to the same file review and
/// revert as one. Contents are kept as raw bytes: a revert restores exactly
/// what was there. With a store, originals survive a relaunch; a storage
/// failure is logged and never blocks the agent (tracking continues in memory).
actor ChangeTracker: FileChangeRecording {
    private struct Entry {
        let projectRoot: URL
        /// `nil` when the file did not exist.
        let original: Data?
    }

    private var entries: [URL: Entry] = [:]
    private let store: (any ChangeOriginalsStore)?
    /// Loads saved originals once; every operation waits for it first.
    private var restoration: Task<Void, Never>?

    init(store: (any ChangeOriginalsStore)? = nil) {
        self.store = store
    }

    func willModify(_ file: URL, in projectRoot: URL) async {
        await restoreIfNeeded()
        guard entries[file] == nil else { return }
        let entry = Entry(projectRoot: projectRoot, original: FileManager.default.contents(atPath: file.path))
        entries[file] = entry
        await persist { try await $0.save(TrackedOriginal(file: file, projectRoot: projectRoot, content: entry.original)) }
    }

    func didModify(_ file: URL, in projectRoot: URL) {}

    /// Files changed in a project, with their diff. Files whose content went
    /// back to the original are not listed.
    func changes(in projectRoot: URL) async -> [FileChange] {
        await restoreIfNeeded()
        return entries.compactMap { file, entry -> FileChange? in
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
    func accept(_ file: URL) async {
        await restoreIfNeeded()
        await forget(file)
    }

    /// Restores the original content (or removes a created file).
    func revert(_ file: URL) async throws {
        await restoreIfNeeded()
        guard let entry = entries[file] else { return }
        if let original = entry.original {
            try original.write(to: file, options: .atomic)
        } else if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        await forget(file)
    }

    func acceptAll(in projectRoot: URL) async {
        await restoreIfNeeded()
        for (file, entry) in entries where entry.projectRoot == projectRoot {
            await forget(file)
        }
    }

    /// Reverts every change in the project; stops at the first failure.
    func revertAll(in projectRoot: URL) async throws {
        await restoreIfNeeded()
        for (file, entry) in entries where entry.projectRoot == projectRoot {
            try await revert(file)
        }
    }

    // MARK: Persistence

    private func forget(_ file: URL) async {
        entries[file] = nil
        await persist { try await $0.delete(file: file) }
    }

    private func restoreIfNeeded() async {
        if restoration == nil {
            restoration = Task { await self.restore() }
        }
        await restoration?.value
    }

    /// Saved originals win over ones captured meanwhile: they are older, so
    /// they are the content from before the agent's first change.
    private func restore() async {
        guard let store else { return }
        do {
            for original in try await store.allOriginals() {
                entries[original.file] = Entry(projectRoot: original.projectRoot, original: original.content)
            }
        } catch {
            Logger(category: .persistence).error("Could not restore tracked changes: \(error)")
        }
    }

    private func persist(_ operation: (any ChangeOriginalsStore) async throws -> Void) async {
        guard let store else { return }
        do {
            try await operation(store)
        } catch {
            Logger(category: .persistence).error("Could not save tracked changes: \(error)")
        }
    }
}
