import Foundation

/// Read access to project files for the Files tab. Implemented in
/// `Infrastructure/FileSystem`, with the same skipping rules as the agent's
/// tools (dependencies, hidden files, `.gitignore`).
protocol ProjectFileBrowsing: Sendable {
    /// Relative paths of the project's files, sorted.
    func files(in projectRoot: URL) async throws -> [String]
    /// Text content of a file, refusing binaries and very large files.
    func contents(of path: String, in projectRoot: URL) async throws -> String
}
