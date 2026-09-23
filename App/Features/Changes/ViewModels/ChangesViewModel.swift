import Foundation
import Observation

/// Review of the agent's changes in one project: list, diff, accept, revert.
@MainActor
@Observable
final class ChangesViewModel {
    let projectRoot: URL
    private(set) var changes: [FileChange] = []
    var selectedFile: URL?
    var error: UserFacingError?

    private let tracker: ChangeTracker

    init(projectRoot: URL, tracker: ChangeTracker) {
        self.projectRoot = projectRoot
        self.tracker = tracker
    }

    var selectedChange: FileChange? {
        changes.first { $0.file == selectedFile } ?? changes.first
    }

    var totals: (added: Int, removed: Int) {
        changes.reduce((0, 0)) { ($0.0 + $1.diff.addedLines, $0.1 + $1.diff.removedLines) }
    }

    func refresh() async {
        changes = await tracker.changes(in: projectRoot)
        if let selectedFile, !changes.contains(where: { $0.file == selectedFile }) { self.selectedFile = nil }
    }

    func accept(_ change: FileChange) async {
        await tracker.accept(change.file)
        await refresh()
    }

    func revert(_ change: FileChange) async {
        do {
            try await tracker.revert(change.file)
        } catch {
            self.error = UserFacingError(error, title: "Could not revert \(change.path)", category: .tools)
        }
        await refresh()
    }

    func acceptAll() async {
        await tracker.acceptAll(in: projectRoot)
        await refresh()
    }

    func revertAll() async {
        do {
            try await tracker.revertAll(in: projectRoot)
        } catch {
            self.error = UserFacingError(error, title: "Could not revert all changes", category: .tools)
        }
        await refresh()
    }
}
