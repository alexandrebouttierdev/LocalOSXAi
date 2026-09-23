import SwiftUI

/// A compact, expandable row describing one tool call and its result.
struct ToolCallView: View {
    let call: ToolCallRecord
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                header
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tool \(call.name), \(statusText)")
            .accessibilityHint(isExpanded ? "Collapses the output" : "Shows the output")

            if isExpanded {
                Divider().overlay(AppColors.border)
                detail
            }
        }
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
        .appAnimation(AppAnimation.standard, value: isExpanded)
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            statusIcon
                .frame(width: 14)
            Text(call.name)
                .font(AppTypography.code)
                .foregroundStyle(AppColors.textPrimary)
            Text(call.argumentsJSON)
                .font(AppTypography.code)
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: AppSpacing.sm)
            if let summary = call.summary {
                Text(summary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xxs)
        .frame(minHeight: AppLayout.rowHeight)
        .contentShape(Rectangle())
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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
            }
            .frame(maxHeight: 200)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch call.status {
        case .running:
            ProgressView().controlSize(.mini)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.success)
        case .failed:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(AppColors.danger)
        case .denied:
            Image(systemName: "hand.raised.fill").foregroundStyle(AppColors.warning)
        case .awaitingApproval:
            Image(systemName: "questionmark.circle.fill").foregroundStyle(AppColors.warning)
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
