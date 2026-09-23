import SwiftUI

/// Centered placeholder for empty or not-yet-available content.
///
/// Deliberately restrained: one muted icon, a title, one sentence and at most
/// a couple of actions. No illustrations.
struct EmptyStateView<Actions: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 56, height: 56)
                .appGlass(in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.display)
                    .foregroundStyle(AppColors.textPrimary)
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            actions
                .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(systemImage: String, title: String, message: String) {
        self.init(systemImage: systemImage, title: title, message: message) { EmptyView() }
    }
}
