import Foundation
import Observation

/// Git state of the selected project, shown in the inspector.
@MainActor
@Observable
final class GitViewModel {
    enum State: Equatable {
        case loading
        case notARepository
        case loaded(GitStatus, lastCommit: GitCommit?)
        case failed(String)
    }

    let projectRoot: URL
    private(set) var state: State = .loading
    private let git: any GitService

    init(projectRoot: URL, git: any GitService) {
        self.projectRoot = projectRoot
        self.git = git
    }

    func refresh() async {
        do {
            async let status = git.status(in: projectRoot)
            async let commits = git.log(in: projectRoot, limit: 1)
            state = .loaded(try await status, lastCommit: try await commits.first)
        } catch GitError.notARepository {
            state = .notARepository
        } catch {
            state = .failed(UserFacingError(error, title: "Git status failed", category: .git).message)
        }
    }
}
