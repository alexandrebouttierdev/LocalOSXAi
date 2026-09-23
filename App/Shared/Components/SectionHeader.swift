import SwiftUI

/// Title of a sidebar or inspector section, with an optional trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: AppSpacing.xs)
            accessory
        }
        .frame(minHeight: 20)
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}
