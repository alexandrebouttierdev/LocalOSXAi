import Foundation
import Synchronization
@testable import LocalOSXAi

/// A scenario-driven provider for agent and integration tests.
///
/// Each call to `stream(request:)` consumes the next scripted `Turn`, which
/// lets a test describe a whole agent loop (“first a tool call, then an
/// answer”) without a real model. It also records every request and counts
/// streams that were cancelled while producing.
///
/// Compared to `MockLLMProvider` (a closure returning fixed events), the fake
/// models *time*: delays, hangs, timeouts and partial streams.
final class FakeLLMProvider: LLMProvider {
    enum Turn: Sendable {
        /// One text chunk, then `.finished(.stop)`.
        case response(String)
        /// Several text chunks separated by `delay`, then `.finished(.stop)`.
        case streaming([String], delay: Duration = .zero)
        /// The given tool calls, then `.finished(.toolCalls)`.
        case toolCalls([LLMToolCall])
        /// A single tool call whose arguments are not valid JSON.
        case malformedToolCall(name: String, rawArguments: String)
        /// Fails immediately.
        case failure(ProviderError)
        /// Streams some text, then fails mid-stream.
        case failureAfter([String], ProviderError)
        /// Waits `after`, then fails with `.timedOut`.
        case timeout(after: Duration)
        /// Never produces anything; ends only when cancelled.
        case hang
        /// Emits exactly these events, then finishes.
        case events([LLMEvent])
    }

    private struct State {
        var turns: [Turn]
        var models: Result<[AIModel], ProviderError>
        var requests: [LLMRequest] = []
        var cancelledStreams = 0
    }

    let descriptor: ProviderDescriptor
    private let state: Mutex<State>

    init(id: ProviderID = "fake", displayName: String = "Fake", models: [AIModel] = [], turns: [Turn] = []) {
        descriptor = ProviderDescriptor(id: id, displayName: displayName, endpoint: nil)
        state = Mutex(State(turns: turns, models: .success(models)))
    }

    var requests: [LLMRequest] { state.withLock { $0.requests } }
    var cancelledStreams: Int { state.withLock { $0.cancelledStreams } }

    func failListingModels(with error: ProviderError) {
        state.withLock { $0.models = .failure(error) }
    }

    func enqueue(_ turns: Turn...) {
        state.withLock { $0.turns.append(contentsOf: turns) }
    }

    func listModels() async throws -> [AIModel] {
        try state.withLock { $0.models }.get()
    }

    func stream(request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        let turn = state.withLock { state -> Turn? in
            state.requests.append(request)
            return state.turns.isEmpty ? nil : state.turns.removeFirst()
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let turn else { throw ProviderError.invalidResponse("FakeLLMProvider: no scripted turn left") }
                    try await Self.play(turn, into: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    self.state.withLock { $0.cancelledStreams += 1 }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func play(_ turn: Turn, into continuation: AsyncThrowingStream<LLMEvent, Error>.Continuation) async throws {
        switch turn {
        case .response(let text):
            continuation.yield(.textDelta(text))
            continuation.yield(.finished(.stop))
        case .streaming(let chunks, let delay):
            for chunk in chunks {
                try await Task.sleep(for: delay)
                continuation.yield(.textDelta(chunk))
            }
            continuation.yield(.finished(.stop))
        case .toolCalls(let calls):
            calls.forEach { continuation.yield(.toolCall($0)) }
            continuation.yield(.finished(.toolCalls))
        case let .malformedToolCall(name, rawArguments):
            continuation.yield(.toolCall(LLMToolCall(id: "malformed-1", name: name, rawArguments: rawArguments)))
            continuation.yield(.finished(.toolCalls))
        case .failure(let error):
            throw error
        case let .failureAfter(chunks, error):
            chunks.forEach { continuation.yield(.textDelta($0)) }
            throw error
        case .timeout(let delay):
            try await Task.sleep(for: delay)
            throw ProviderError.timedOut
        case .hang:
            try await Task.sleep(for: .seconds(3_600))
        case .events(let events):
            events.forEach { continuation.yield($0) }
        }
    }
}
