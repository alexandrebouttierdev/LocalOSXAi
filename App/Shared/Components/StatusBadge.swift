import SwiftUI

/// Semantic tone of a status indicator.
enum StatusTone: Sendable {
    case neutral
    case accent
    case success
    case warning
    case danger

    var color: Color {
        switch self {
        case .neutral: AppColors.textSecondary
        case .accent: AppColors.accent
        case .success: AppColors.success
        case .warning: AppColors.warning
        case .danger: AppColors.danger
        }
    }
}

/// A compact status label that always pairs color with an icon and text, so
/// state is never conveyed by color alone (docs/ui/accessibility.md).
struct StatusBadge: View {
    let title: String
    let systemImage: String
    var tone: StatusTone = .neutral

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(AppColors.textSecondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tone.color)
        }
        .font(AppTypography.caption)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, AppSpacing.sm - 2)
        .padding(.vertical, AppSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
    }
}
