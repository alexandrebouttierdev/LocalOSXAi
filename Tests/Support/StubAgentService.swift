import Foundation
import Synchronization
@testable import LocalOSXAi

/// An `AgentService` returning scripted events, for view model tests.
final class StubAgentService: AgentService {
    enum Behavior: Sendable {
        /// Emits the events, then finishes.
        case events([AgentEvent])
        /// Emits the events, then fails with `error`.
        case failAfter([AgentEvent], any Error)
        /// Emits the events, then waits until cancelled.
        case hangAfter([AgentEvent])
    }

    private let behavior: Behavior
    private let recordedRequests = Mutex<[AgentRunRequest]>([])
    private let cancellations = Mutex(0)

    init(_ behavior: Behavior) {
        self.behavior = behavior
    }

    var requests: [AgentRunRequest] { recordedRequests.withLock { $0 } }
    var cancellationCount: Int { cancellations.withLock { $0 } }

    func run(_ request: AgentRunRequest) -> AsyncThrowingStream<AgentEvent, Error> {
        recordedRequests.withLock { $0.append(request) }
        let behavior = self.behavior
        return AsyncThrowingStream { continuation in
            let task = Task {
                switch behavior {
                case .events(let events):
                    events.forEach { continuation.yield($0) }
                    continuation.finish()
                case let .failAfter(events, error):
                    events.forEach { continuation.yield($0) }
                    continuation.finish(throwing: error)
                case .hangAfter(let events):
                    events.forEach { continuation.yield($0) }
                    do {
                        try await Task.sleep(for: .seconds(3_600))
                        continuation.finish()
                    } catch {
                        self.cancellations.withLock { $0 += 1 }
                        continuation.finish(throwing: CancellationError())
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
