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
                if !message.toolCalls.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(message.toolCalls) { call in
                            ToolCallView(call: call)
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
            switch message.state {
            case .streaming:
                Text(message.text.isEmpty && message.toolCalls.isEmpty ? "Thinking…" : "Working…")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
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
        Label {
            Text(message.text)
                .foregroundStyle(AppColors.textPrimary)
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

/// Collapsible model reasoning, collapsed by default to keep answers scannable.
private struct ReasoningView: View {
    let text: String
    let isStreaming: Bool
    @State private var isExpanded = false

    var body: some View {
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
