import SwiftUI

/// Asks the user to allow or deny a tool call, floating above the composer.
///
/// Keyboard: ⌘↩ allows once, ⌘⌫ denies. The reason is stated in text so the
/// consequence of allowing is always explicit.
struct ApprovalBanner: View {
    let request: ToolApprovalRequest
    let onDecision: (ToolApprovalDecision) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.warning)
                .frame(width: 30, height: 30)
                .background(AppColors.warning.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(request.summary)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text(request.reason)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: AppSpacing.sm)
            AppGlassContainer {
                HStack(spacing: AppSpacing.xs) {
                    Button("Deny") { onDecision(.deny) }
                        .appGlassButton()
                        .keyboardShortcut(.delete, modifiers: .command)
                        .help("Deny (⌘⌫)")
                    Button("Allow for Session") { onDecision(.allowForSession) }
                        .appGlassButton()
                        .help("Don't ask again for \(request.toolName) in this session.")
                    Button("Allow") { onDecision(.allowOnce) }
                        .appGlassButton(prominent: true)
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Allow (⌘↩)")
                }
            }
            .controlSize(.regular)
        }
        .padding(AppSpacing.md)
        .appGlass(.tinted(AppColors.warning), in: RoundedRectangle(cornerRadius: AppRadius.composer, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Approval needed: \(request.summary). \(request.reason)")
    }
}
