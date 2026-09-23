import SwiftUI

/// Renders one transcript entry.
///
/// Text is displayed as plain, selectable text. Markdown rendering is
/// deliberately deferred to Phase 6: it must be parsed off the render path
/// and cached, not recomputed in `body` on every streamed token.
struct AgentMessageView: View {
    let message: AgentMessage

    var body: some View {
        switch message.role {
        case .user: userMessage
        case .assistant: assistantMessage
        case .error: errorMessage
        }
    }

    private var userMessage: some View {
        Text(message.text)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
            )
            .accessibilityLabel("You: \(message.text)")
    }

    private var assistantMessage: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header
            if !message.reasoning.isEmpty {
                ReasoningView(text: message.reasoning, isStreaming: message.state == .streaming && message.text.isEmpty)
            }
            ForEach(message.toolCalls) { call in
                ToolCallView(call: call)
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("Agent")
                .font(AppTypography.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
            switch message.state {
            case .streaming:
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel("Responding")
            case .cancelled:
                StatusBadge(title: "Stopped", systemImage: "stop.circle", tone: .neutral)
            case .failed:
                StatusBadge(title: "Failed", systemImage: "xmark.octagon", tone: .danger)
            case .complete:
                EmptyView()
            }
        }
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
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(AppColors.danger.opacity(0.4), lineWidth: AppBorders.hairline)
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
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, AppSpacing.xs)
        } label: {
            Text(isStreaming ? "Thinking…" : "Thought process")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textTertiary)
        }
    }
}
