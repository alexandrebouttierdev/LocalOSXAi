import Foundation

/// `ProjectFileBrowsing` on the local filesystem.
struct LocalFileBrowser: ProjectFileBrowsing {
    static let maxFiles = 20_000

    func files(in projectRoot: URL) async throws -> [String] {
        try ProjectFileWalker(root: projectRoot).files(in: projectRoot, limit: Self.maxFiles).entries.map(\.path)
    }

    func contents(of path: String, in projectRoot: URL) async throws -> String {
        let url = try ProjectBoundary.resolve(path, in: projectRoot)
        return try TextFileReader.read(url, relativePath: path)
    }
}
