import Foundation
import Synchronization
@testable import LocalOSXAi

/// A closure-driven provider for tests that assert on *what was sent*.
///
/// The handler computes the response events from the request synchronously,
/// and every request is recorded. Use `FakeLLMProvider` instead when a test
/// needs delays, hangs, timeouts or multi-turn scripts.
final class MockLLMProvider: LLMProvider {
    typealias Handler = @Sendable (LLMRequest) throws -> [LLMEvent]

    let descriptor: ProviderDescriptor
    private let modelsResult: Result<[AIModel], ProviderError>
    private let handler: Handler
    private let recordedRequests = Mutex<[LLMRequest]>([])
    private let listModelsCalls = Mutex(0)

    init(
        id: ProviderID = "mock",
        displayName: String = "Mock",
        supportsContextLength: Bool = false,
        models: Result<[AIModel], ProviderError> = .success([]),
        handler: @escaping Handler = { _ in [.finished(.stop)] }
    ) {
        descriptor = ProviderDescriptor(id: id, displayName: displayName, endpoint: nil, supportsContextLength: supportsContextLength)
        modelsResult = models
        self.handler = handler
    }

    var receivedRequests: [LLMRequest] { recordedRequests.withLock { $0 } }
    var listModelsCallCount: Int { listModelsCalls.withLock { $0 } }

    func listModels() async throws -> [AIModel] {
        listModelsCalls.withLock { $0 += 1 }
        return try modelsResult.get()
    }

    func stream(request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error> {
        recordedRequests.withLock { $0.append(request) }
        let result = Result { try handler(request) }
        return AsyncThrowingStream { continuation in
            switch result {
            case .success(let events):
                events.forEach { continuation.yield($0) }
                continuation.finish()
            case .failure(let error):
                continuation.finish(throwing: error)
            }
        }
    }
}
