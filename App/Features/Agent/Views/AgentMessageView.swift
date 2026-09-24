import SwiftUI

/// Renders one transcript entry.
///
/// Streaming text is shown as plain text; once a message is complete its
/// Markdown is rendered (paragraphs, lists, headings, code blocks). Parsing
/// finished messages only keeps every streamed token cheap to display.
struct AgentMessageView: View {
    let message: AgentMessage
    /// False for follow-up messages of the same agent turn.
    var showsHeader = true

    var body: some View {
        switch message.role {
        case .user: userMessage
        case .assistant: assistantMessage
        case .error: errorMessage
        }
    }

    private var userMessage: some View {
        HStack {
            Spacer(minLength: AppSpacing.xxl * 2)
            Text(message.text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, AppSpacing.md + AppSpacing.xxs)
                .padding(.vertical, AppSpacing.sm + AppSpacing.xxs)
                .background(AppColors.accentSubtle, in: RoundedRectangle(cornerRadius: AppRadius.bubble, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You: \(message.text)")
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
                    ReasoningView(text: message.reasoning, isStreaming: message.state == .streaming && message.text.isEmpty)
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
            }
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
            case .streaming:
                StreamingStatusView(message: message)
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
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(AppColors.danger.opacity(0.35), lineWidth: AppBorders.hairline)
        )
        .accessibilityLabel("Error: \(message.text)")
    }
}

/// What the agent is doing while a message streams, with the elapsed time
/// when nothing has arrived yet (a model may take a while to load).
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
        let seconds = max(Int(now.timeIntervalSince(message.createdAt)), 0)
        if message.text.isEmpty, message.reasoning.isEmpty, message.toolCalls.isEmpty, message.preparingToolCall == nil {
            return seconds < 5 ? "Waiting for the model…" : "Waiting for the model… \(seconds) s (it may be loading)"
        }
        if message.preparingToolCall != nil { return "Preparing a tool call… \(seconds) s" }
        if message.text.isEmpty, message.toolCalls.isEmpty { return "Thinking… \(seconds) s" }
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

/// Collapsible model reasoning, collapsed by default to keep answers
/// scannable; while it streams, its latest lines show as a live preview.
private struct ReasoningView: View {
    let text: String
    let isStreaming: Bool
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            disclosure
            if isStreaming, !isExpanded {
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
            Label(isStreaming ? "Thinking…" : "Thought process", systemImage: "brain")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textTertiary)
        }
     }
}
