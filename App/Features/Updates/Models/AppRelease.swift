import Foundation

/// A published release of the app, as the update check found it.
struct AppRelease: Hashable, Sendable {
    let version: AppVersion
    /// The tag, e.g. “v0.0.0.2”.
    let tag: String
    let title: String
    /// Release notes in Markdown, cut to `maxNotesLength`.
    let notes: String
    /// The release's page, where the user downloads it. Always on the app's
    /// own repository: the checker replaces any other address.
    let pageURL: URL
    let publishedAt: Date?

    /// Enough for a long changelog; the full notes are on the release page.
    static let maxNotesLength = 6_000
}

/// Why checking for updates failed, in words the user can act on.
enum UpdateCheckError: Error, Equatable, LocalizedError {
    /// No connection, or the server could not be reached in time.
    case unreachable
    /// Nothing has been published yet.
    case noRelease
    /// GitHub limits unauthenticated requests per network address.
    case rateLimited
    case server(status: Int)
    /// The answer was not a release the app understands.
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unreachable: "GitHub could not be reached."
        case .noRelease: "No release has been published yet."
        case .rateLimited: "GitHub is limiting requests from this network for now."
        case .server(let status): "GitHub answered with an error (HTTP \(status))."
        case .invalidResponse: "GitHub's answer could not be read."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unreachable: "Check your internet connection, then try again."
        case .noRelease: nil
        case .rateLimited: "Try again in an hour, or look at the Releases page on GitHub."
        case .server, .invalidResponse: "Try again later, or look at the Releases page on GitHub."
        }
    }
}
