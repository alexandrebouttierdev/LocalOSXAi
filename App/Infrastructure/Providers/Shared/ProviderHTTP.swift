import Foundation

/// HTTP plumbing shared by network providers: request building, status
/// validation and translation of transport failures into `ProviderError`.
///
/// Kept as free functions over `URLSession` rather than a custom transport
/// protocol: tests substitute the network with a `URLProtocol` stub, so no
/// extra abstraction is needed (docs/ai/providers.md).
enum ProviderHTTP {
    /// Maximum error body read from a failed streaming response.
    private static let maxErrorBodyBytes = 4_096

    /// A session for model servers.
    ///
    /// `timeoutIntervalForRequest` is URLSession's *idle* timeout: it fires
    /// when no byte arrives for that long, which is exactly the "model stopped
    /// responding" condition. It must be generous because loading a model or
    /// evaluating a long prompt can take minutes before the first token.
    static func makeSession(idleTimeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = idleTimeout
        configuration.timeoutIntervalForResource = 60 * 60
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    static func request(_ url: URL, method: String = "GET", body: JSONValue? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(body.serialized().utf8)
        }
        return request
    }

    /// Performs a request and returns the body of a successful response.
    static func data(for request: URLRequest, session: URLSession) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response, body: data)
            return data
        } catch {
            throw translate(error, request: request)
        }
    }

    /// Performs a streaming request and returns its body as lines.
    ///
    /// Non-success responses are fully mapped to `ProviderError` before any
    /// line is returned, so callers only ever iterate a successful stream.
    static func lines(for request: URLRequest, session: URLSession) async throws -> AsyncLineSequence<URLSession.AsyncBytes> {
        do {
            let (bytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                var body = Data()
                for try await byte in bytes {
                    body.append(byte)
                    if body.count >= maxErrorBodyBytes { break }
                }
                try validate(response, body: body)
            }
            return bytes.lines
        } catch {
            throw translate(error, request: request)
        }
    }

    /// Maps transport errors to `ProviderError`, and URL cancellation to
    /// `CancellationError` so the cancellation contract holds.
    static func translate(_ error: any Error, request: URLRequest) -> any Error {
        if error is ProviderError || error is CancellationError { return error }
        guard let urlError = error as? URLError else { return error }
        let endpoint = request.url.map { "\($0.scheme ?? "http")://\($0.host ?? "")\($0.port.map { ":\($0)" } ?? "")" } ?? "?"
        switch urlError.code {
        case .cancelled:
            return CancellationError()
        case .timedOut:
            return ProviderError.timedOut
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet,
             .dnsLookupFailed, .badServerResponse, .secureConnectionFailed:
            return ProviderError.unreachable(endpoint: endpoint)
        default:
            return ProviderError.invalidResponse(urlError.localizedDescription)
        }
    }

    /// Throws a `ProviderError` for non-2xx responses, using the server's
    /// error message when it provides one (`{"error": "..."}` from Ollama,
    /// `{"error": {"message": "..."}}` from OpenAI-compatible servers).
    static func validate(_ response: URLResponse, body: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse("Not an HTTP response")
        }
        guard !(200..<300).contains(http.statusCode) else { return }
        let message = errorMessage(in: body)
        throw classify(status: http.statusCode, message: message)
    }

    static func errorMessage(in body: Data) -> String? {
        guard let text = String(bytes: body, encoding: .utf8), let json = try? JSONValue.parse(text) else {
            let raw = String(bytes: body.prefix(300), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return raw?.isEmpty == false ? raw : nil
        }
        let error = json.objectValue?["error"]
        return error?.stringValue ?? error?.objectValue?["message"]?.stringValue
    }

    /// Recognizes the failures the agent can act on from the server message.
    static func classify(status: Int, message: String?) -> ProviderError {
        let lowered = message?.lowercased() ?? ""
        if lowered.contains("does not support tools") {
            return .unsupportedCapability("tool calling")
        }
        if status == 404 || (lowered.contains("model") && lowered.contains("not found")) {
            return .modelNotFound(message ?? "unknown model")
        }
        return .httpStatus(code: status, message: message)
    }
}
