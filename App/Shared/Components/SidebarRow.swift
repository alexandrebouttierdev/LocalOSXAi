import SwiftUI

/// A row of a Linear-style sidebar: full width, 6 pt corners, a faint hover
/// and a neutral selection. Never the system accent: a saturated selection
/// would be the loudest thing on screen.
struct SidebarRow<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var label: Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs + AppSpacing.xxs)
                .frame(minHeight: AppLayout.rowHeight)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(isSelected ? AppColors.selection : (isHovered ? AppColors.hover : .clear))
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
