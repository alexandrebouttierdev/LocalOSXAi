import Foundation

/// A folder the user opened as a workspace for the agent.
///
/// `rootURL` is always standardized and symlink-resolved: it is the boundary
/// every tool enforces, so two spellings of the same folder must compare equal.
struct Project: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var rootURL: URL
    let createdAt: Date
    var lastOpenedAt: Date
}

/// Errors raised while opening or managing projects.
enum ProjectError: Error, Hashable, Sendable {
    case folderNotFound(path: String)
    case notAFolder(path: String)
}

extension ProjectError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .folderNotFound(let path): "The folder “\(path)” does not exist."
        case .notAFolder(let path): "“\(path)” is a file, not a folder."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .folderNotFound: "It may have been moved or deleted. Choose the folder again."
        case .notAFolder: "Choose the folder that contains your project."
        }
    }
}
