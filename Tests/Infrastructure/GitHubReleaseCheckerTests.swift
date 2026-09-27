import Foundation
import Testing
@testable import LocalOSXAi

/// The update check against a stub of GitHub's API: decoding, the request
/// sent, HTTP errors, untrusted page addresses, offline and cancellation.
@Suite("GitHubReleaseChecker", .timeLimit(.minutes(1)))
struct GitHubReleaseCheckerTests {
    private static let latest = """
        {"tag_name": "v0.0.0.2", "name": "LocalOSXAi v0.0.0.2", "draft": false, "prerelease": false,
         "html_url": "https://github.com/alexandrebouttierdev/LocalOSXAi/releases/tag/v0.0.0.2",
         "published_at": "2026-09-27T14:00:00Z", "body": "## What's Changed\\n* Update check"}
        """

    private func checker(_ route: StubURLProtocol.Route) -> GitHubReleaseChecker {
        GitHubReleaseChecker(owner: "alexandrebouttierdev", repository: "LocalOSXAi", appVersion: "0.0.0.1",
                             apiBase: route.baseURL, session: route.session())
    }

    @Test("reads the latest release from the repository's endpoint")
    func latestRelease() async throws {
        let route = StubURLProtocol.route { _ in .json(Self.latest) }

        let release = try await checker(route).latestRelease()

        #expect(release.version == AppVersion("0.0.0.2"))
        #expect(release.tag == "v0.0.0.2")
        #expect(release.title == "LocalOSXAi v0.0.0.2")
        #expect(release.notes == "## What's Changed\n* Update check")
        #expect(release.pageURL.absoluteString == "https://github.com/alexandrebouttierdev/LocalOSXAi/releases/tag/v0.0.0.2")
        #expect(release.publishedAt == Date(timeIntervalSince1970: 1_790_517_600))

        let request = try #require(route.requests.first)
        #expect(request.method == "GET")
        #expect(request.path == "/repos/alexandrebouttierdev/LocalOSXAi/releases/latest")
        #expect(request.headers["User-Agent"] == "LocalOSXAi/0.0.0.1")
        #expect(request.headers["Accept"] == "application/vnd.github+json")
        #expect(request.authorization == nil)
    }

    @Test("a page outside the repository's releases is replaced by the latest release page", arguments: [
        "https://evil.example/LocalOSXAi/releases/tag/v0.0.0.2",
        "http://github.com/alexandrebouttierdev/LocalOSXAi/releases/tag/v0.0.0.2",
        "https://github.com/someone/else/releases/tag/v0.0.0.2",
        "file:///Applications"
    ])
    func untrustedPage(page: String) async throws {
        let body = #"{"tag_name": "v0.0.0.2", "html_url": "\#(page)"}"#
        let route = StubURLProtocol.route { _ in .json(body) }

        let release = try await checker(route).latestRelease()

        #expect(release.pageURL.absoluteString == "https://github.com/alexandrebouttierdev/LocalOSXAi/releases/latest")
        #expect(release.title == "v0.0.0.2")
        #expect(release.notes.isEmpty)
    }

    @Test("long notes are cut")
    func longNotes() async throws {
        let notes = String(repeating: "a", count: AppRelease.maxNotesLength + 500)
        let route = StubURLProtocol.route { _ in .json(#"{"tag_name": "v1.0", "body": "\#(notes)"}"#) }
        let release = try await checker(route).latestRelease()
        #expect(release.notes.count == AppRelease.maxNotesLength)
    }

    @Test("HTTP errors and unreadable answers become update errors", arguments: [
        (StubURLProtocol.Response.json(#"{"message": "Not Found"}"#, status: 404), UpdateCheckError.noRelease),
        (.json(#"{"message": "API rate limit exceeded"}"#, status: 403), .rateLimited),
        (.json("{}", status: 429), .rateLimited),
        (.json("{}", status: 502), .server(status: 502)),
        (.json("<html>"), .invalidResponse),
        (.json(#"{"tag_name": "nightly"}"#), .invalidResponse),
        (.failure(.notConnectedToInternet), .unreachable),
        (.failure(.timedOut), .unreachable)
    ] as [(StubURLProtocol.Response, UpdateCheckError)])
    func failures(response: StubURLProtocol.Response, expected: UpdateCheckError) async {
        let route = StubURLProtocol.route { _ in response }
        await #expect(throws: expected) {
            try await checker(route).latestRelease()
        }
    }

    @Test("cancelling the task stops the request")
    func cancellation() async {
        let route = StubURLProtocol.route { _ in StubURLProtocol.Response(hangs: true) }
        let checker = checker(route)
        let task = Task { try await checker.latestRelease() }
        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
