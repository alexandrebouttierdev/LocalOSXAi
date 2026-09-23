import Foundation
import Synchronization
@testable import LocalOSXAi

/// Replaces the network for provider tests.
///
/// Each test registers a route under a unique host and receives a
/// `URLSession` whose requests to that host are answered by its handler, so
/// tests stay isolated while running in parallel. Responses can be streamed
/// in chunks, delayed, left hanging (to test cancellation) or fail with a
/// `URLError`.
///
/// `@unchecked Sendable`: URLSession drives a protocol instance from its own
/// loader thread; the instance only reads immutable route data and the
/// `loadingTask` handle, which `startLoading`/`stopLoading` access sequentially.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        var status = 200
        var chunks: [String] = []
        var chunkDelay: Duration = .zero
        /// Keep the connection open after the chunks instead of finishing.
        var hangs = false
        var error: URLError?

        static func json(_ body: String, status: Int = 200) -> Response {
            Response(status: status, chunks: [body])
        }

        static func failure(_ code: URLError.Code) -> Response {
            Response(error: URLError(code))
        }
    }

    struct CapturedRequest: Sendable {
        let method: String
        let path: String
        let body: JSONValue?
    }

    typealias Handler = @Sendable (CapturedRequest) -> Response

    final class Route: Sendable {
        let host = "stub-\(UUID().uuidString.lowercased()).test"
        fileprivate let handler: Handler
        private let captured = Mutex<[CapturedRequest]>([])
        private let stops = Mutex(0)

        fileprivate init(handler: @escaping Handler) {
            self.handler = handler
        }

        var baseURL: URL {
            guard let url = URL(string: "http://\(host)") else { preconditionFailure("Invalid stub host") }
            return url
        }

        var requests: [CapturedRequest] { captured.withLock { $0 } }
        var stopCount: Int { stops.withLock { $0 } }

        fileprivate func record(_ request: CapturedRequest) { captured.withLock { $0.append(request) } }
        fileprivate func recordStop() { stops.withLock { $0 += 1 } }

        /// A session routed to this stub.
        func session(idleTimeout: TimeInterval = 30) -> URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            configuration.timeoutIntervalForRequest = idleTimeout
            return URLSession(configuration: configuration)
        }
    }

    private static let routes = Mutex<[String: Route]>([:])

    static func route(_ handler: @escaping Handler) -> Route {
        let route = Route(handler: handler)
        routes.withLock { $0[route.host] = route }
        return route
    }

    private var loadingTask: Task<Void, Never>?
    private var activeRoute: Route?

    override static func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return routes.withLock { $0[host] != nil }
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let route = Self.routes.withLock({ $0[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        activeRoute = route
        let captured = CapturedRequest(
            method: request.httpMethod ?? "GET",
            path: url.path(),
            body: Self.body(of: request).flatMap { try? JSONValue.parse($0) }
        )
        route.record(captured)
        let response = route.handler(captured)

        if let error = response.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: "HTTP/1.1",
                                         headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)

        // The compiler does not treat an `@unchecked Sendable` subclass of a
        // non-Sendable Objective-C class as sendable; see the type comment.
        let instance = UncheckedReference(value: self)
        loadingTask = Task { await instance.value.deliver(response) }
    }

    private func deliver(_ response: Response) async {
        for chunk in response.chunks {
            if response.chunkDelay > .zero { try? await Task.sleep(for: response.chunkDelay) }
            if Task.isCancelled { return }
            client?.urlProtocol(self, didLoad: Data(chunk.utf8))
        }
        if response.hangs {
            try? await Task.sleep(for: .seconds(3_600))
            return
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        loadingTask?.cancel()
        activeRoute?.recordStop()
    }

    /// URLSession moves the body to `httpBodyStream` before protocols see it.
    private static func body(of request: URLRequest) -> String? {
        if let data = request.httpBody { return String(bytes: data, encoding: .utf8) }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return String(bytes: data, encoding: .utf8)
    }
}

private struct UncheckedReference<Value: AnyObject>: @unchecked Sendable {
    let value: Value
}
