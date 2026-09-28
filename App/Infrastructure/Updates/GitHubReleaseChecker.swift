import Foundation

/// Asks GitHub's REST API for the repository's latest release.
///
/// `GET /repos/{owner}/{repo}/releases/latest` never returns drafts or
/// pre-releases, so the per-push pre-releases of `release.yml` are not
/// offered as updates. The request is anonymous and carries nothing about the
/// user's projects: only the app's name and version in `User-Agent`, which
/// GitHub requires (docs/decisions/0030-update-check.md).
///
/// The response is untrusted input: the tag must parse as a version, and the
/// page opened for the user is always on this repository's releases.
struct GitHubReleaseChecker: ReleaseChecking {
    private let apiURL: URL
    private let releasesPage: URL
    private let pagePathPrefix: String
    private let userAgent: String
    private let session: URLSession

    /// - Parameters:
    ///   - owner, repository: e.g. “alexandrebouttierdev”, “LocalOSXAi”.
    ///   - apiBase: GitHub's API, or a stub server in tests.
    init(owner: String, repository: String, appVersion: String,
         apiBase: URL? = nil, session: URLSession? = nil) {
        let base = apiBase ?? URL(string: "https://api.github.com") ?? URL(fileURLWithPath: "/")
        apiURL = base.appending(path: "repos/\(owner)/\(repository)/releases/latest")
        pagePathPrefix = "/\(owner)/\(repository)/releases/"
        releasesPage = URL(string: "https://github.com\(pagePathPrefix)latest") ?? URL(fileURLWithPath: "/")
        userAgent = "LocalOSXAi/\(appVersion)"
        self.session = session ?? Self.makeSession()
    }

    func latestRelease() async throws -> AppRelease {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw UpdateCheckError.unreachable
        }
        try Task.checkCancellation()

        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: return try release(from: data)
        case 404: throw UpdateCheckError.noRelease
        case 403, 429: throw UpdateCheckError.rateLimited
        case let status: throw UpdateCheckError.server(status: status)
        }
    }

    private struct Payload: Decodable {
        let tagName: String
        let name: String?
        let body: String?
        let htmlURL: String?
        let publishedAt: Date?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case body
            case htmlURL = "html_url"
            case publishedAt = "published_at"
        }
    }

    private func release(from data: Data) throws -> AppRelease {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(Payload.self, from: data),
              let version = AppVersion(payload.tagName) else {
            throw UpdateCheckError.invalidResponse
        }
        let title = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return AppRelease(
            version: version,
            tag: payload.tagName,
            title: title.isEmpty ? payload.tagName : title,
            notes: String((payload.body ?? "").prefix(AppRelease.maxNotesLength)),
            pageURL: safePage(payload.htmlURL),
            publishedAt: payload.publishedAt
        )
    }

    /// The release's own page when it is on this repository over HTTPS,
    /// otherwise the repository's latest release.
    private func safePage(_ text: String?) -> URL {
        guard let text, let url = URL(string: text), url.scheme == "https", url.host() == "github.com",
              url.path().hasPrefix(pagePathPrefix) else {
            return releasesPage
        }
        return url
    }

    /// Short timeouts: the check runs in the background and is retried at
    /// the next launch, so it should never hang on a bad network.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
