import SwiftUI

/// “Update” at the bottom of the sidebar when a newer version was found, like
/// Linear's: an accent pill that opens the update window. The word carries
/// the meaning, the color only draws the eye.
struct UpdateBadge: View {
    let release: AppRelease
    let action: () -> Void
    @State private var isHovered = false

    private static let borderOpacity = 0.3
    private static let hoveredBorderOpacity = 0.6

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "arrow.down.circle.fill")
                    .accessibilityHidden(true)
                Text("Update")
                    .fontWeight(.medium)
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.accentText)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs + 1)
            .background(Capsule().fill(AppColors.accentSubtle))
            .overlay(
                Capsule().strokeBorder(AppColors.accent.opacity(isHovered ? Self.hoveredBorderOpacity : Self.borderOpacity),
                                       lineWidth: AppBorders.hairline)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { isHovered = $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
        .help("LocalOSXAi \(release.tag) is available")
        .accessibilityLabel("Update available: LocalOSXAi \(release.version.description)")
        .accessibilityHint("Shows the new version and how to download it")
    }
}
