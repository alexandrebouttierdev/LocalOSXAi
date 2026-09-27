import SwiftUI

/// Linear's view switcher (“Activity · Guide · Diff”): a row of pill
/// buttons, the selected one on a raised fill.
struct PillPicker<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Text(title(option))
                        .font(AppTypography.callout.weight(.medium))
                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .frame(height: AppLayout.buttonHeight)
                        .background(Capsule().fill(isSelected ? AppColors.selection : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .appAnimation(AppAnimation.quick, value: selection)
    }
}
