import Foundation
import Observation

/// Browsing and quick-opening project files (⌘P).
@MainActor
@Observable
final class FilesViewModel {
    enum Preview: Equatable {
        case none
        case loading
        case text(String)
        case unavailable(String)
    }

    static let maxResults = 300

    let projectRoot: URL
    private(set) var files: [String] = []
    private(set) var isLoading = false
    private(set) var selectedPath: String?
    private(set) var preview: Preview = .none
    var query = "" {
        didSet { recompute() }
    }
    private(set) var results: [String] = []
    /// Incremented to ask the view to focus the search field (⌘P).
    private(set) var searchFocusRequest = 0

    private let browser: any ProjectFileBrowsing

    init(projectRoot: URL, browser: any ProjectFileBrowsing) {
        self.projectRoot = projectRoot
        self.browser = browser
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            files = try await browser.files(in: projectRoot)
        } catch {
            files = []
            preview = .unavailable(UserFacingError(error, title: "Could not list files", category: .tools).message)
        }
        recompute()
    }

    func requestSearchFocus() {
        searchFocusRequest += 1
    }

    func select(_ path: String) async {
        selectedPath = path
        preview = .loading
        do {
            let text = try await browser.contents(of: path, in: projectRoot)
            guard selectedPath == path else { return }
            preview = .text(text)
        } catch {
            guard selectedPath == path else { return }
            preview = .unavailable((error as? LocalizedError)?.errorDescription ?? "The file cannot be previewed.")
        }
    }

    /// Paths ranked by fuzzy match on the whole path, file name matches first.
    private func recompute() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = Array(files.prefix(Self.maxResults))
            return
        }
        results = files
            .compactMap { path -> (String, Int)? in
                let name = (path as NSString).lastPathComponent
                let nameScore = FuzzyMatcher.score(trimmed, in: name).map { $0 + 20 }
                guard let score = [nameScore, FuzzyMatcher.score(trimmed, in: path)].compactMap({ $0 }).max() else { return nil }
                return (path, score)
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.count < $1.0.count }
            .prefix(Self.maxResults)
            .map(\.0)
    }
}
