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
    /// The icon's hue (`AppColors.Hue`), like Linear's colored property icons.
    var tint: Color = AppColors.textSecondary
    @ViewBuilder var icon: Icon
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
            icon
                .foregroundStyle(tint)
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
    init(_ text: String, systemImage: String, isPlaceholder: Bool = false, isInteractive: Bool = true,
         tint: Color = AppColors.textSecondary) {
        self.init(text: text, isPlaceholder: isPlaceholder, isInteractive: isInteractive, tint: tint) {
            Image(systemName: systemImage)
        }
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

/// A Linear label: a colored dot and a word, on a hairline pill.
struct PropertyLabel: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: AppSpacing.sm, height: AppSpacing.sm)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(AppColors.textPrimary)
        }
        .font(AppTypography.caption)
        .padding(.horizontal, AppSpacing.sm)
        .frame(height: AppLayout.rowHeight - AppSpacing.sm)
        .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: AppBorders.hairline))
    }
}
