import Foundation

/// Builds and budgets the messages sent to the model during a run.
///
/// Priorities (docs/ai/context.md): the system prompt with project
/// instructions and the new request are never dropped; the current run's
/// messages come next; earlier conversation is dropped oldest first. Before
/// dropping anything from the current run, large results of earlier tool
/// calls are truncated. Summarizing old history happens before a run starts
/// (`HistoryCompaction`), so this type only ever drops what is left.
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
    var promptBudget: Int { Self.promptBudget(contextTokens: contextTokens) }

    static func promptBudget(contextTokens: Int) -> Int {
        let reserve = max(Int(Double(contextTokens) * outputReserveRatio), minimumOutputReserve)
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

/// Decides how much earlier conversation to summarize before a run.
///
/// Summarizing costs a model call, so it happens once, before the run, and
/// only when the conversation already fills a share of the prompt budget
/// (half by default, Settings › General): the rest stays free for this run's
/// tool calls and results, which would otherwise push history out one
/// iteration at a time. The user can also summarize everything at once
/// (“Compact session”), which `AgentRuntime` does without this type.
enum HistoryCompaction {
    /// Default share of the prompt budget a run may start with before summarizing.
    static let defaultStartRatio = 0.5
    /// Latest history messages always kept verbatim: the last exchange.
    static let keptRecentMessages = 2
    /// A summary is not worth a model call for less than one exchange.
    static let minimumSummarizedMessages = 2

    /// Tokens a summary may take: an eighth of the prompt budget, at most 1K.
    static func summaryTokens(promptBudget: Int) -> Int {
        min(1_024, promptBudget / 8)
    }

    /// How many of the oldest `history` messages to replace with a summary,
    /// or 0 when the run fits or nothing can usefully be summarized.
    ///
    /// The cut always falls before a user message, so the history kept
    /// verbatim never starts with an answer. It is the smallest cut that
    /// brings the start of the run under `startRatio`, else the largest one.
    ///
    /// - Parameters:
    ///   - fixedTokens: the system prompt without any summary, plus the new request.
    ///   - currentSummaryTokens: the summary already in use, which a new one replaces.
    ///   - startRatio: share of `promptBudget` the run may start with.
    static func messagesToSummarize(history: [LLMMessage], fixedTokens: Int, currentSummaryTokens: Int,
                                    promptBudget: Int, startRatio: Double = defaultStartRatio) -> Int {
        let target = Int(Double(promptBudget) * startRatio)
        let sizes = history.map { TokenEstimator.estimate(messages: [$0.content]) }
        guard fixedTokens + currentSummaryTokens + sizes.reduce(0, +) > target,
              history.count - keptRecentMessages >= minimumSummarizedMessages else { return 0 }
        let cuts = (minimumSummarizedMessages...(history.count - keptRecentMessages)).filter { history[$0].role == .user }
        guard let largest = cuts.last else { return 0 }
        let allowance = summaryTokens(promptBudget: promptBudget)
        return cuts.first { fixedTokens + allowance + sizes[$0...].reduce(0, +) <= target } ?? largest
    }
}

/// Converts the transcript and project into model messages.
enum AgentPrompt {
    /// The conversation a run starts from: the latest summary, if any, and
    /// the messages after it, each with the transcript message it came from.
    struct History: Sendable, Hashable {
        struct Entry: Sendable, Hashable {
            let messageID: UUID
            let message: LLMMessage
        }

        var summary: String?
        var entries: [Entry]

        var messages: [LLMMessage] { entries.map(\.message) }
    }

    static func system(projectName: String, instructions: [ProjectInstruction], toolsEnabled: Bool) -> String {
        var prompt = """
            You are a careful software engineering agent working in the project “\(projectName)”. \
            Paths are relative to the project root. Today is \(Date().formatted(date: .complete, time: .omitted)).
            """
        if toolsEnabled {
            prompt += """


                Use the tools to inspect the project before answering questions about its code; never \
                invent file contents. Read a file before editing it, and prefer edit_file for small \
                changes. Write a file longer than about 150 lines in several steps: create it with a \
                first part, then add the rest with edit_file, so no single call is too long to \
                finish. Some actions need the user's approval: if one is denied, do not retry it. \
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

    /// The system prompt with the summary of earlier conversation, if any.
    ///
    /// The summary goes in the system message rather than in a message of
    /// its own: many chat templates reject two user messages in a row.
    static func system(_ system: String, summary: String?) -> String {
        guard let summary else { return system }
        return system + "\n\n# Earlier conversation (summary)\n\n" + summary
    }

    /// Earlier conversation as model messages, starting after the latest
    /// complete summary. Tool calls of earlier runs are summarized in one
    /// line each rather than replayed, which keeps history cheap while
    /// telling the model what it already did.
    static func history(from messages: [AgentMessage]) -> History {
        let summaryIndex = messages.lastIndex { $0.role == .summary && $0.state == .complete }
        let start = summaryIndex.map { $0 + 1 } ?? messages.startIndex
        let entries = messages[start...].compactMap { message -> History.Entry? in
            llmMessage(from: message).map { History.Entry(messageID: message.id, message: $0) }
        }
        return History(summary: summaryIndex.map { messages[$0].text }, entries: entries)
    }

    private static func llmMessage(from message: AgentMessage) -> LLMMessage? {
        switch message.role {
        case .user:
            return .user(userContent(message.text, attachments: message.attachments))
        case .assistant where message.state != .failed:
            let tools = message.toolCalls.map { "- \($0.name) \($0.argumentsJSON) → \($0.summary ?? $0.status.rawValue)" }
            let text = tools.isEmpty ? message.text : "[Tools used]\n" + tools.joined(separator: "\n") + "\n\n" + message.text
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .assistant(text)
        case .assistant, .error, .summary:
            return nil
        }
    }

    /// A user message as the model reads it: the text, then each attached
    /// file in a `<file>` block with its path, so the model can refer to it
    /// and, for a project file, edit it with its tools.
    static func userContent(_ text: String, attachments: [MessageAttachment]) -> String {
        guard !attachments.isEmpty else { return text }
        let files = attachments.map { file in
            var block = "<file path=\"\(file.path)\">\n\(file.content)\n</file>"
            if file.isTruncated {
                block += "\n[Only the first \(MessageAttachment.maxCharacters) characters of \(file.name) were attached.]"
            }
            return block
        }
        let header = attachments.count == 1 ? "Attached file:" : "Attached files:"
        return ([text, header] + files).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// The request asking the model to summarize `messages`, folding in the
    /// previous summary so one summary always covers everything before it.
    /// The conversation is cut in the middle when it exceeds `maxInputTokens`.
    static func summaryRequest(previousSummary: String?, messages: [LLMMessage], maxInputTokens: Int,
                               maxSummaryTokens: Int) -> [LLMMessage] {
        let words = maxSummaryTokens * 3 / 4
        let instructions = """
            You summarize a conversation between a user and a software engineering agent, so the agent \
            can continue the work without the original messages. Keep: the user's goals and decisions, \
            constraints and preferences they stated, files read or changed and why, commands run and \
            their outcome, open problems and next steps. Drop pleasantries and repeated content. Write \
            plain text in short sections, at most \(words) words. Do not add anything that was not said.
            """
        var conversation = messages.map { message in
            (message.role == .user ? "User: " : "Agent: ") + message.content
        }.joined(separator: "\n\n")
        if let previousSummary {
            conversation = "Summary of what came before:\n\(previousSummary)\n\n" + conversation
        }
        let maxCharacters = max(maxInputTokens - TokenEstimator.estimate(instructions), 0) * TokenEstimator.charactersPerToken
        let limited = OutputLimiter.limit(conversation, maxCharacters: maxCharacters, note: "middle of the conversation omitted")
        return [.system(instructions), .user("Summarize this conversation:\n\n" + limited)]
    }
}
