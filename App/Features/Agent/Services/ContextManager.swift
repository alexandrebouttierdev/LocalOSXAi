import Foundation

/// Builds and budgets the messages sent to the model during a run.
///
/// Priorities (docs/ai/context.md): the system prompt with project
/// instructions and the new request are never dropped; the current run's
/// messages come next; earlier conversation is dropped oldest first. Before
/// dropping anything from the current run, large results of earlier tool
/// calls are truncated. Conversation summarization is not implemented yet.
struct RunContext: Sendable {
    /// Share of the context reserved for the model's answer.
    static let outputReserveRatio = 0.25
    static let minimumOutputReserve = 1_024
    /// Size kept (head + tail) of a tool result when compacting.
    static let compactedToolOutputCharacters = 1_500

    let contextTokens: Int
    private let system: LLMMessage
    private var history: [LLMMessage]
    /// The user's request followed by this run's assistant and tool messages.
    private var turn: [LLMMessage]

    init(contextTokens: Int, systemPrompt: String, history: [LLMMessage], prompt: String) {
        self.contextTokens = contextTokens
        system = .system(systemPrompt)
        self.history = history
        turn = [.user(prompt)]
    }

    /// Tokens available for the prompt.
    var promptBudget: Int {
        let reserve = max(Int(Double(contextTokens) * Self.outputReserveRatio), Self.minimumOutputReserve)
        return max(contextTokens - reserve, 0)
    }

    mutating func appendAssistant(text: String, toolCalls: [LLMToolCall]) {
        turn.append(.assistant(text, toolCalls: toolCalls))
    }

    mutating func appendToolResult(_ output: String, callID: String, toolName: String) {
        turn.append(.tool(output, callID: callID, toolName: toolName))
    }

    /// Returns messages that fit the budget, compacting as needed, and their
    /// estimated size.
    ///
    /// - Throws: `AgentError.contextOverflow` when even the system prompt,
    ///   the request and the current run's messages cannot fit.
    mutating func fittedMessages() throws -> (messages: [LLMMessage], estimatedTokens: Int) {
        let budget = promptBudget
        var total = estimate()

        // 1. Shorten large arguments of tool calls already executed (e.g. a whole
        //    file passed to write_file): the result says what happened.
        for index in turn.indices where !turn[index].toolCalls.isEmpty && total > budget {
            turn[index].toolCalls = turn[index].toolCalls.map { call in
                let arguments = PartialJSON.compactingLongStrings(in: call.rawArguments,
                                                                  maxLength: Self.compactedToolOutputCharacters)
                return LLMToolCall(id: call.id, name: call.name, rawArguments: arguments)
            }
            total = estimate()
        }
        // 2. Truncate tool results, oldest first, keeping the latest one intact.
        let toolIndices = turn.indices.filter { turn[$0].role == .tool }.dropLast()
        for index in toolIndices where total > budget {
            let compacted = OutputLimiter.limit(turn[index].content, maxCharacters: Self.compactedToolOutputCharacters,
                                               note: "earlier output truncated to save context")
            guard compacted.count < turn[index].content.count else { continue }
            turn[index].content = compacted
            total = estimate()
        }
        // 3. Drop earlier conversation, oldest first, never leaving an orphan answer first.
        while total > budget, !history.isEmpty {
            history.removeFirst()
            while history.first?.role == .assistant { history.removeFirst() }
            total = estimate()
        }
        guard total <= budget else {
            throw AgentError.contextOverflow(usedTokens: total, budgetTokens: budget)
        }
        return ([system] + history + turn, total)
    }

    private func estimate() -> Int {
        TokenEstimator.estimate(messages: ([system] + history + turn).map { message in
            message.content + message.toolCalls.map { $0.name + $0.rawArguments }.joined()
        })
    }
}

/// Converts the transcript and project into model messages.
enum AgentPrompt {
    static func system(projectName: String, instructions: [ProjectInstruction], toolsEnabled: Bool) -> String {
        var prompt = """
            You are a careful software engineering agent working in the project “\(projectName)”. \
            Paths are relative to the project root. Today is \(Date().formatted(date: .complete, time: .omitted)).
            """
        if toolsEnabled {
            prompt += """


                Use the tools to inspect the project before answering questions about its code; never \
                invent file contents. Read a file before editing it, and prefer edit_file for small \
                changes. Some actions need the user's approval: if one is denied, do not retry it. \
                When the task is done, answer briefly and say which files you changed.
                """
        } else {
            prompt += """


                You cannot read or modify files with this model: answer from the conversation only, \
                and say when you would need to inspect code.
                """
        }
        for instruction in instructions {
            prompt += "\n\n# Project instructions (\(instruction.source))\n\n\(instruction.content)"
            if instruction.isTruncated { prompt += "\n\n[\(instruction.source) was truncated.]" }
        }
        return prompt
    }

    /// Earlier conversation as model messages. Tool calls of earlier runs
    /// are summarized in one line each rather than replayed, which keeps
    /// history cheap while telling the model what it already did.
    static func history(from messages: [AgentMessage]) -> [LLMMessage] {
        messages.compactMap { message in
            switch message.role {
            case .user:
                return .user(message.text)
            case .assistant where message.state != .failed:
                let tools = message.toolCalls.map { "- \($0.name) \($0.argumentsJSON) → \($0.summary ?? $0.status.rawValue)" }
                let text = tools.isEmpty ? message.text : "[Tools used]\n" + tools.joined(separator: "\n") + "\n\n" + message.text
                return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .assistant(text)
            case .assistant, .error:
                return nil
            }
        }
    }
}
