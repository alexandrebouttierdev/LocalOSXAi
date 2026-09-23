import Foundation

/// Runs one tool call requested by a model: lookup, argument validation,
/// permission, approval, execution with a timeout, output limiting.
///
/// It never throws for a *failed call*: every failure becomes an `Outcome`
/// whose output is sent back to the model, so the model can correct itself
/// (docs/ai/tools.md). It contains no tool-specific logic.
struct ToolExecutor: Sendable {
    struct Outcome: Hashable, Sendable {
        let status: ToolCallRecord.Status
        let summary: String
        /// What the model receives as the tool result.
        let output: String
        /// True when the call could not even be attempted (unknown tool,
        /// malformed or invalid arguments). Counted by the runtime to stop
        /// models stuck in a loop of invalid calls.
        let isInvalidCall: Bool
    }

    let registry: ToolRegistry
    let policy: ToolPermissionPolicy
    let timeout: Duration
    let maxOutputCharacters: Int

    init(registry: ToolRegistry, policy: ToolPermissionPolicy = ToolPermissionPolicy(),
         timeout: Duration = .seconds(30), maxOutputCharacters: Int = 16_000) {
        self.registry = registry
        self.policy = policy
        self.timeout = timeout
        self.maxOutputCharacters = maxOutputCharacters
    }

    /// - Parameter statusChanged: reports `.awaitingApproval` and `.running`
    ///   transitions so the UI can show them.
    func execute(
        _ call: LLMToolCall,
        context: ToolContext,
        approver: any ToolApprover,
        statusChanged: @Sendable (ToolCallRecord.Status) -> Void
    ) async -> Outcome {
        let tool: any AgentTool
        let arguments: ToolArguments
        do {
            tool = try registry.tool(named: call.name)
            arguments = try ToolArguments.parse(call.rawArguments)
            try tool.parameters.validate(arguments)
        } catch {
            return invalid(error, toolName: call.name)
        }

        switch policy.permission(for: tool, arguments: arguments) {
        case .allowed:
            break
        case .blocked(let reason):
            return Outcome(status: .denied, summary: "Blocked", output: "Blocked by policy: \(reason) Do not retry.", isInvalidCall: false)
        case .requiresApproval(let reason):
            statusChanged(.awaitingApproval)
            let request = ToolApprovalRequest(id: call.id, toolName: tool.name,
                                              summary: tool.describe(arguments: arguments), reason: reason)
            let decision = await approver.decide(request)
            if Task.isCancelled { return cancelled }
            guard decision != .deny else {
                return Outcome(
                    status: .denied, summary: "Denied by the user",
                    output: "The user denied this action. Do not retry it; continue without it or ask the user how to proceed.",
                    isInvalidCall: false
                )
            }
        }

        statusChanged(.running)
        do {
            let result = try await Self.withTimeout(timeout) {
                try await tool.execute(arguments: arguments, context: context)
            }
            let output = OutputLimiter.limit(result.output, maxCharacters: maxOutputCharacters)
            return Outcome(status: result.status == .success ? .succeeded : .failed, summary: result.summary,
                           output: output, isInvalidCall: false)
        } catch is CancellationError {
            return cancelled
        } catch let error as ToolError {
            if Task.isCancelled { return cancelled }
            let message = error.errorDescription ?? "The tool failed."
            // Argument errors raised during execution are also the model's to fix.
            return Outcome(status: .failed, summary: message, output: "Error: \(message)", isInvalidCall: Self.isArgumentError(error))
        } catch {
            if Task.isCancelled { return cancelled }
            return Outcome(status: .failed, summary: "Failed", output: "Error: \(error.localizedDescription)", isInvalidCall: false)
        }
    }

    private var cancelled: Outcome {
        Outcome(status: .cancelled, summary: "Cancelled", output: "Cancelled by the user.", isInvalidCall: false)
    }

    private func invalid(_ error: any Error, toolName: String) -> Outcome {
        var message = (error as? LocalizedError)?.errorDescription ?? "Invalid tool call."
        if case ToolError.unknownTool = error {
            message += " Available tools: \(registry.names.joined(separator: ", "))."
        }
        return Outcome(status: .failed, summary: message, output: "Error: \(message) Fix the call and try again.", isInvalidCall: true)
    }

    private static func isArgumentError(_ error: ToolError) -> Bool {
        switch error {
        case .malformedArguments, .missingArgument, .invalidArgument, .unexpectedArgument: true
        default: false
        }
    }

    /// Races `operation` against a timer. Tools must honor cancellation for
    /// the timeout to interrupt them: a task group waits for its children.
    static func withTimeout<Value: Sendable>(
        _ duration: Duration,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw ToolError.timedOut(seconds: Double(duration.components.seconds))
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else { throw CancellationError() }
            return value
        }
    }
}
