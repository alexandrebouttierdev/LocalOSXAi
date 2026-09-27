import SwiftUI

/// Asks the user to allow or deny a tool call, floating above the composer.
///
/// Keyboard: ⌘↩ allows once, ⌘⌫ denies. The reason is stated in text so the
/// consequence of allowing is always explicit.
struct ApprovalBanner: View {
    let request: ToolApprovalRequest
    let onDecision: (ToolApprovalDecision) -> Void

    /// Lines of the proposed change shown before scrolling.
    static let diffHeight: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header
            if let preview = request.preview {
                DiffView(diff: preview.diff, path: preview.path, badge: preview.isNewFile ? "New file" : nil,
                         maxHeight: Self.diffHeight)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                            .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
                    )
            }
        }
        .padding(AppSpacing.md)
        .appFloating(.tinted(AppColors.warning), in: RoundedRectangle(cornerRadius: AppRadius.composer, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.composer, style: .continuous)
                .strokeBorder(AppColors.warning.opacity(0.35), lineWidth: AppBorders.hairline)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Approval needed: \(request.summary). \(request.reason)")
    }

    private var header: some View {
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
            Group {
                HStack(spacing: AppSpacing.xs) {
                    Button("Deny") { onDecision(.deny) }
                        .appButton()
                        .keyboardShortcut(.delete, modifiers: .command)
                        .help("Deny (⌘⌫)")
                    if let rule = request.suggestedCommandRule {
                        Menu("Allow for Session") {
                            Button("Always Allow “\(rule)” in This Project") { onDecision(.allowCommandInProject(rule)) }
                        } primaryAction: {
                            onDecision(.allowForSession)
                        }
                        .fixedSize()
                        .help("Allow \(request.toolName) for this session, or always allow “\(rule)” in this project. "
                              + "Blocked commands stay blocked.")
                    } else {
                        Button("Allow for Session") { onDecision(.allowForSession) }
                            .appButton()
                            .help("Don't ask again for \(request.toolName) in this session.")
                    }
                    Button("Allow") { onDecision(.allowOnce) }
                        .appButton(prominent: true)
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Allow (⌘↩)")
                }
            }
            .controlSize(.regular)
        }
    }
}
