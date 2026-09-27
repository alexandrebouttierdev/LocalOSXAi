import SwiftUI

/// Renders one transcript entry.
///
/// Streaming text is shown as plain text; once a message is complete its
/// Markdown is rendered (paragraphs, lists, headings, code blocks). Parsing
/// finished messages only keeps every streamed token cheap to display.
/// Equatable, so the transcript skips messages that did not change while
/// another one streams.
struct AgentMessageView: View, Equatable {
    let message: AgentMessage
    /// False for follow-up messages of the same agent turn.
    var showsHeader = true
    /// Set on the last message of a turn: its duration and tokens.
    var turnStats: TurnStats?

    var body: some View {
        switch message.role {
        case .user: userMessage
        case .assistant: assistantMessage
        case .error: errorMessage
        case .summary: ConversationSummaryView(message: message)
        }
    }

    private var userMessage: some View {
        HStack {
            Spacer(minLength: AppSpacing.xxl * 2)
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .padding(.horizontal, AppSpacing.md + AppSpacing.xxs)
                        .padding(.vertical, AppSpacing.sm + AppSpacing.xxs)
                        .background(AppColors.surfaceRaised,
                                    in: RoundedRectangle(cornerRadius: AppRadius.bubble, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.bubble, style: .continuous)
                                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
                        )
                }
                if !message.attachments.isEmpty {
                    FlowLayout(spacing: AppSpacing.xs) {
                        ForEach(message.attachments) { AttachmentChip(attachment: $0) }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(userAccessibilityLabel)
    }

    private var userAccessibilityLabel: String {
        let files = message.attachments.map(\.name).joined(separator: ", ")
        return "You: \(message.text)" + (files.isEmpty ? "" : ". Attached: \(files)")
    }

    private var assistantMessage: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Group {
                if showsHeader {
                    AgentAvatar(isWorking: message.state == .streaming)
                } else {
                    Color.clear.frame(width: 22, height: 1)
                }
            }
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if showsHeader || message.state != .complete {
                    header
                }
                if !message.reasoning.isEmpty {
                    ReasoningView(text: message.reasoning, isThinking: activity == .thinking, since: message.createdAt)
                }
                if !message.toolCalls.isEmpty || message.preparingToolCall != nil {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(message.toolCalls) { call in
                            ToolCallView(call: call)
                        }
                        if let draft = message.preparingToolCall {
                            PreparingToolCallView(draft: draft)
                        }
                    }
                }
                // Below finished tool calls: the model is deciding what comes next.
                if let activity, activity != .thinking {
                    ActivityIndicator(title: activity.title, systemImage: Self.symbol(for: activity),
                                      since: activity == .waitingForModel ? message.createdAt : nil, hint: activity.hint)
                        .transition(.opacity)
                }
                if !message.text.isEmpty {
                    if message.state == .streaming {
                        Text(message.text)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        MarkdownText(message.text)
                    }
                }
                if let turnStats {
                    TurnStatsView(stats: turnStats)
                }
            }
        }
    }

    /// What the message is waiting on, shown as a loader in its body.
    private var activity: StreamingActivity? { StreamingActivity(message) }

    private static func symbol(for activity: StreamingActivity) -> String {
        switch activity {
        case .waitingForModel: "hourglass"
        case .thinking: "brain"
        case .nextStep: "arrow.triangle.branch"
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("Agent")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
                // Headings let VoiceOver users jump between turns with the rotor.
                .accessibilityAddTraits(.isHeader)
            switch message.state {
            case .streaming where activity == nil:
                StreamingStatusView(message: message)
            case .streaming:
                EmptyView()
            case .cancelled:
                StatusBadge(title: "Stopped", systemImage: "stop.circle", tone: .neutral)
            case .failed:
                StatusBadge(title: "Failed", systemImage: "xmark.octagon", tone: .danger)
            case .complete:
                EmptyView()
            }
        }
        .frame(minHeight: 22)
    }

    private var errorMessage: some View {
        let lines = message.text.split(separator: "\n", maxSplits: 1).map(String.init)
        return Label {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(lines.first ?? "")
                    .foregroundStyle(AppColors.textPrimary)
                if lines.count > 1 {
                    Text(lines[1])
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .textSelection(.enabled)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.danger)
        }
        .font(AppTypography.body)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm + AppSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Quiet, like Linear's inline errors: the icon carries the color; the
        // surface stays neutral with a faint red wash.
        .background(AppColors.danger.opacity(0.05), in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
        .accessibilityLabel("Error: \(message.text)")
    }
}

/// What the agent is doing while a message streams and output is visible
/// (text, a tool call being written or run). Waiting and thinking have a
/// loader of their own (`StreamingActivity`).
private struct StreamingStatusView: View {
    let message: AgentMessage

    var body: some View {
        TimelineView(.periodic(from: message.createdAt, by: 1)) { context in
            Text(label(now: context.date))
                .font(AppTypography.caption.monospacedDigit())
                .foregroundStyle(AppColors.textTertiary)
                .contentTransition(.numericText())
        }
    }

    private func label(now: Date) -> String {
        let elapsed = DurationFormatter.string(now.timeIntervalSince(message.createdAt))
        if message.preparingToolCall != nil { return "Preparing a tool call… \(elapsed)" }
        return "Working…"
    }
}

/// A tool call the model is still writing, e.g. a whole file for write_file.
private struct PreparingToolCallView: View {
    let draft: ToolCallDraft

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ProgressView().controlSize(.mini)
            Text(title)
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: AppSpacing.sm)
            Text("\(TokenCountFormatter.string(for: draft.characters)) characters")
                .font(AppTypography.caption.monospacedDigit())
                .foregroundStyle(AppColors.textTertiary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xxs)
        .frame(minHeight: 32)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.border, style: StrokeStyle(lineWidth: AppBorders.hairline, dash: [4, 3]))
        )
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        let target = draft.path ?? "a file"
        switch draft.name {
        case "write_file": return "Writing \(target)…"
        case "edit_file": return "Preparing an edit of \(target)…"
        case "run_command": return "Preparing a command…"
        default: return "Preparing \(draft.name)…"
        }
    }
}

/// Where the model's view of the conversation starts: messages above were
/// summarized. Collapsed by default; while the model writes the summary, the
/// elapsed time shows that the run is not stuck.
private struct ConversationSummaryView: View {
    let message: AgentMessage
    @State private var isExpanded = false

    var body: some View {
        if message.state == .streaming {
            HStack(spacing: AppSpacing.sm) {
                ProgressView().controlSize(.mini)
                TimelineView(.periodic(from: message.createdAt, by: 1)) { context in
                    let elapsed = DurationFormatter.string(context.date.timeIntervalSince(message.createdAt))
                    Text("Summarizing the conversation… \(elapsed)")
                        .font(AppTypography.callout.monospacedDigit())
                        .foregroundStyle(AppColors.textTertiary)
                        .contentTransition(.numericText())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Summarizing the conversation")
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                MarkdownText(message.text)
                    .padding(.leading, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(AppColors.border).frame(width: 2)
                    }
                    .padding(.top, AppSpacing.xs)
            } label: {
                Label("Conversation summarized: the model now sees this summary instead of the messages above",
                      systemImage: "text.append")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .help("The messages above stay in the session; only the model's copy was summarized.")
        }
    }
}

/// Collapsible model reasoning, collapsed by default to keep answers
/// scannable; while it streams, its latest lines show as a live preview.
private struct ReasoningView: View {
    let text: String
    /// The model is still reasoning: the label becomes the thinking loader.
    let isThinking: Bool
    let since: Date
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            disclosure
            if isThinking, !isExpanded {
                Text(Self.tail(of: text))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, AppSpacing.lg)
                    .accessibilityHidden(true)
            }
        }
    }

    /// The last 200 characters, on one line.
    static func tail(of text: String) -> String {
        String(text.suffix(200)).replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    }

    private var disclosure: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(text)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .overlay(alignment: .leading) {
                    Rectangle().fill(AppColors.border).frame(width: 2)
                }
                .padding(.top, AppSpacing.xs)
        } label: {
            if isThinking {
                ActivityIndicator(title: "Thinking", systemImage: "brain", since: since)
            } else {
                Label("Thought process", systemImage: "brain")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
     }
}

/// “12.4 s · 356 tokens” under an agent turn; ticks every second while the
/// turn streams, with an estimated (“~”) count until the server reports one.
private struct TurnStatsView: View {
    let stats: TurnStats

    var body: some View {
        Group {
            if stats.end == nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    label(stats.summary(now: context.date))
                }
            } else {
                label(stats.summary(now: .now))
            }
        }
        .font(AppTypography.caption.monospacedDigit())
        .foregroundStyle(AppColors.textTertiary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stats.end == nil ? "Running" : "Took \(stats.accessibilityDescription)")
        .help(stats.isEstimated ? "~ marks an estimate: the server did not report its token count."
                                : "Output tokens as counted by the server.")
    }

    private func label(_ text: String) -> some View {
        Label(text, systemImage: "clock")
            .labelStyle(.titleAndIcon)
    }
}
