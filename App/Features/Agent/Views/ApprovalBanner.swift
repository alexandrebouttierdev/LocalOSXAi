import SwiftUI

/// Asks the user to allow or deny a tool call, floating above the composer.
///
/// Keyboard: ⌘↩ allows once, ⌘⌫ denies. The reason is stated in text so the
/// consequence of allowing is always explicit.
struct ApprovalBanner: View {
    let request: ToolApprovalRequest
    let onDecision: (ToolApprovalDecision) -> Void

    @State private var showsChanges = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header
            if let preview = request.preview {
                DisclosureGroup(isExpanded: $showsChanges) {
                    ScrollView([.vertical, .horizontal]) {
                        DiffView(diff: preview.diff)
                            .padding(.vertical, AppSpacing.xs)
                    }
                    .frame(maxHeight: 240)
                    .background(AppColors.codeBackground, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Text(preview.isNewFile ? "New file" : "Changes")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                        DiffStatView(added: preview.diff.addedLines, removed: preview.diff.removedLines)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .appGlass(.tinted(AppColors.warning), in: RoundedRectangle(cornerRadius: AppRadius.composer, style: .continuous))
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
            AppGlassContainer {
                HStack(spacing: AppSpacing.xs) {
                    Button("Deny") { onDecision(.deny) }
                        .appGlassButton()
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
                            .appGlassButton()
                            .help("Don't ask again for \(request.toolName) in this session.")
                    }
                    Button("Allow") { onDecision(.allowOnce) }
                        .appGlassButton(prominent: true)
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Allow (⌘↩)")
                }
            }
            .controlSize(.regular)
        }
    }
}
