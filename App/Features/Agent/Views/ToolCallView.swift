import SwiftUI

/// A compact, expandable row describing one tool call in human terms
/// (“Read Makefile”), with its arguments and output available on demand.
struct ToolCallView: View {
    let call: ToolCallRecord
    @State private var isExpanded = false
    @State private var isHovered = false

    private var presentation: ToolCallPresentation { ToolCallPresentation(call) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                header
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .accessibilityLabel("\(presentation.title), \(statusText)")
            .accessibilityHint(isExpanded ? "Collapses the details" : "Shows the details")

            if isExpanded {
                Divider().overlay(AppColors.border)
                detail
                    .transition(.opacity)
            }
        }
        .background(isHovered || isExpanded ? AppColors.hover : .clear,
                    in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
        .appAnimation(AppAnimation.quick, value: isHovered)
        .appAnimation(AppAnimation.standard, value: isExpanded)
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: presentation.systemImage)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(presentation.title)
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let detail = presentation.detail {
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppSpacing.sm)
            if call.status.isFinished, let summary = call.summary, call.status != .succeeded {
                Text(summary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            statusIcon
                .frame(width: 16)
            Image(systemName: "chevron.right")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xxs)
        .frame(minHeight: 32)
        .contentShape(Rectangle())
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let summary = call.summary {
                Text(summary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            labeled("Arguments", call.argumentsJSON)
            if let output = call.output {
                labeled("Output", output)
            }
        }
        .padding(AppSpacing.sm + AppSpacing.xxs)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
            ScrollView {
                Text(value)
                    .font(AppTypography.code)
                    .foregroundStyle(AppColors.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.sm)
            }
            .frame(maxHeight: 220)
            .fixedSize(horizontal: false, vertical: true)
            .background(AppColors.codeBackground, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch call.status {
        case .running:
            ProgressView().controlSize(.mini)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.success)
                .transition(.symbolEffect(.appear))
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(AppColors.danger)
        case .denied:
            Image(systemName: "hand.raised.fill").foregroundStyle(AppColors.warning)
        case .awaitingApproval:
            Image(systemName: "hand.raised.circle").foregroundStyle(AppColors.warning)
                .symbolEffect(.pulse, options: .repeating)
        case .cancelled:
            Image(systemName: "stop.circle").foregroundStyle(AppColors.textTertiary)
        }
    }

    private var statusText: String {
        switch call.status {
        case .running: "running"
        case .succeeded: "succeeded"
        case .failed: "failed"
        case .denied: "denied"
        case .awaitingApproval: "awaiting approval"
        case .cancelled: "cancelled"
        }
    }
}
