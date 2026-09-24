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
        case .accent: AppColors.accentText
        case .success: AppColors.success
        case .warning: AppColors.warning
        case .danger: AppColors.danger
        }
    }
}

/// A compact status label. The text always carries the meaning, so state is
/// never conveyed by color alone (docs/ui/accessibility.md); the icon, or a
/// small dot when there is none, only reinforces it.
///
/// It never wraps: a badge broken mid-word in a narrow column is unreadable.
/// Put several badges in a `FlowLayout` so they move to the next row instead.
struct StatusBadge: View {
    let title: String
    var systemImage: String?
    var tone: StatusTone = .neutral

    var body: some View {
        HStack(spacing: AppSpacing.xs + 1) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tone.color)
                    .accessibilityHidden(true)
            } else if tone != .neutral {
                Circle()
                    .fill(tone.color)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            Text(title)
                .foregroundStyle(AppColors.textSecondary)
        }
        .font(AppTypography.caption)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, AppSpacing.sm - 2)
        .padding(.vertical, AppSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
    }
}
