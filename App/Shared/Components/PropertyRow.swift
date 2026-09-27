import SwiftUI

/// One row of a Linear-style properties panel: a quiet label column and a
/// value, aligned across rows.
struct PropertyRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)
                .frame(width: AppLayout.propertyLabelWidth, alignment: .leading)
            value
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: AppLayout.rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// A property's value: icon and text with no chrome. When it can be changed
/// (a `Menu` label), it highlights on hover like Linear's property buttons.
struct PropertyValue<Icon: View>: View {
    let text: String
    /// Dimmed, for “Default” or “None”.
    var isPlaceholder = false
    /// False for read-only values, which never highlight.
    var isInteractive = true
    @ViewBuilder var icon: Icon
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
            icon
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 16)
            Text(text)
                .foregroundStyle(isPlaceholder ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(AppTypography.callout)
        .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
        .frame(height: AppLayout.rowHeight - AppSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(isHovered ? AppColors.hover : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .onHover { isHovered = isInteractive && $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
    }
}

extension PropertyValue where Icon == Image {
    init(_ text: String, systemImage: String, isPlaceholder: Bool = false, isInteractive: Bool = true) {
        self.init(text: text, isPlaceholder: isPlaceholder, isInteractive: isInteractive) { Image(systemName: systemImage) }
    }
}

extension View {
    /// A `Menu` shown as its label only, as property values are.
    func propertyMenuStyle() -> some View {
        menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
    }
}
