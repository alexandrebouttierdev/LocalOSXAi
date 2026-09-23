import SwiftUI

/// Asks the user to allow or deny a tool call, above the composer.
///
/// Keyboard: ⌘↩ allows once, ⌘⌫ denies. The reason is stated in text so the
/// consequence of allowing is always explicit.
struct ApprovalBanner: View {
    let request: ToolApprovalRequest
    let onDecision: (ToolApprovalDecision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(request.summary)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .textSelection(.enabled)
                    Text(request.reason)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(AppColors.warning)
            }
            HStack(spacing: AppSpacing.sm) {
                Spacer()
                Button("Deny") { onDecision(.deny) }
                    .buttonStyle(.subtle)
                    .keyboardShortcut(.delete, modifiers: .command)
                Button("Allow for This Session") { onDecision(.allowForSession) }
                    .buttonStyle(.subtle)
                    .help("Don't ask again for \(request.toolName) in this session.")
                Button("Allow") { onDecision(.allowOnce) }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(AppColors.warning.opacity(0.5), lineWidth: AppBorders.hairline)
        )
        .frame(maxWidth: AppLayout.readableWidth)
        .padding(.horizontal, AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Approval needed: \(request.summary). \(request.reason)")
    }
}
