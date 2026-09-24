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
        /// Asks the approver, records its decision, then finishes.
        case askApproval(ToolApprovalRequest, decisions: Recorder<ToolApprovalDecision>)
    }

    /// One behavior per run, in order; the last one repeats.
    private let behaviors: [Behavior]
    private let recordedRequests = Mutex<[AgentRunRequest]>([])
    private let cancellations = Mutex(0)

    init(_ behavior: Behavior) {
        behaviors = [behavior]
    }

    init(sequence: [Behavior]) {
        precondition(!sequence.isEmpty, "A stub needs at least one behavior")
        behaviors = sequence
    }

    var requests: [AgentRunRequest] { recordedRequests.withLock { $0 } }
    var cancellationCount: Int { cancellations.withLock { $0 } }

    func run(_ request: AgentRunRequest, approver: any ToolApprover) -> AsyncThrowingStream<AgentEvent, Error> {
        let runIndex = recordedRequests.withLock { requests in
            requests.append(request)
            return requests.count - 1
        }
        let behavior = behaviors[min(runIndex, behaviors.count - 1)]
        return AsyncThrowingStream { continuation in
            let task = Task {
                switch behavior {
                case .events(let events):
                    events.forEach { continuation.yield($0) }
                    continuation.finish()
                case let .failAfter(events, error):
                    events.forEach { continuation.yield($0) }
                    continuation.finish(throwing: error)
                case let .askApproval(request, decisions):
                    let decision = await approver.decide(request)
                    decisions.record(decision)
                    continuation.yield(.finished(.completed))
                    continuation.finish()
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
