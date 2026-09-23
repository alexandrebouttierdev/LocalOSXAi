import SwiftUI

/// Displays a keyboard shortcut (“⌘K”) as a discreet keycap.
///
/// Purely visual: the shortcut itself is registered through menu commands.
/// Hidden from VoiceOver because the owning control already exposes it.
struct ShortcutBadge: View {
    let shortcut: String

    var body: some View {
        Text(shortcut)
            .font(AppTypography.shortcut)
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, AppSpacing.xs)
            .frame(minWidth: 18, minHeight: 18)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
            )
            .accessibilityHidden(true)
    }
}
