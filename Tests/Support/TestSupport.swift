import Foundation
import Synchronization
@testable import LocalOSXAi

/// A uniquely named directory under the system temporary folder.
/// Call `remove()` in a `defer` block.
struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalOSXAiTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    @discardableResult
    func makeDirectory(_ name: String) throws -> URL {
        let directory = url.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    func makeFile(_ name: String, contents: String = "") throws -> URL {
        let file = url.appendingPathComponent(name)
        try Data(contents.utf8).write(to: file)
        return file
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// A manually advanced clock, injected as `now` into services under test.
final class TestClock: Sendable {
    private let current: Mutex<Date>

    init(_ start: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        current = Mutex(start)
    }

    var now: Date { current.withLock { $0 } }

    func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }

    /// A `@Sendable` closure reading this clock.
    var provider: @Sendable () -> Date { { self.now } }
}

/// Thread-safe collector for values produced by `@Sendable` callbacks.
final class Recorder<Value: Sendable>: Sendable {
    private let storage = Mutex<[Value]>([])

    var values: [Value] { storage.withLock { $0 } }

    func record(_ value: Value) {
        storage.withLock { $0.append(value) }
    }
}

/// A minimal tool used to exercise the registry and schema validation.
struct EchoTool: AgentTool {
    var name = "echo"
    var description = "Returns its `text` argument."
    var parameters = ToolParameterSchema(
        properties: ["text": .init(.string, "Text to echo")],
        required: ["text"]
    )
    var effect = ToolEffect.readOnly

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let text = try arguments.string("text")
        return .success(text, summary: "Echoed \(text.count) characters")
    }
}

enum Fixtures {
    static func model(_ name: String, provider: ProviderID = "fake", capabilities: ModelCapabilities = [.streaming],
                      advertised: Int? = nil) -> AIModel {
        AIModel(
            provider: provider,
            name: name,
            displayName: name,
            contextWindow: ContextWindow(advertisedTokens: advertised),
            capabilities: capabilities
        )
    }

    static func project(name: String = "Demo", root: URL = URL(fileURLWithPath: "/tmp/Demo"),
                        openedAt: Date = Date(timeIntervalSinceReferenceDate: 0)) -> Project {
        Project(id: UUID(), name: name, rootURL: root, createdAt: openedAt, lastOpenedAt: openedAt)
    }

    static func session(projectID: Project.ID, title: String = Session.defaultTitle,
                        updatedAt: Date = Date(timeIntervalSinceReferenceDate: 0),
                        messages: [AgentMessage] = []) -> Session {
        Session(id: UUID(), projectID: projectID, title: title, createdAt: updatedAt, updatedAt: updatedAt,
                model: nil, messages: messages)
    }
}

/// Collects every element of a throwing stream, returning the elements seen
/// and the error that ended it, if any.
func collect<Element>(_ stream: AsyncThrowingStream<Element, Error>) async -> (elements: [Element], error: (any Error)?) {
    var elements: [Element] = []
    do {
        for try await element in stream { elements.append(element) }
        return (elements, nil)
    } catch {
        return (elements, error)
    }
}
