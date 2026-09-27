import SwiftUI

/// The About window: the app, its version, its author and its links, from
/// the sidebar's version, the app menu or the command palette.
struct AboutView: View {
    let info: AppInfo
    @Environment(\.dismiss) private var dismiss

    private static let width: CGFloat = 360
    private static let avatarSize: CGFloat = 56

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            AgentAvatar(size: Self.avatarSize)
                .accessibilityHidden(true)
            VStack(spacing: AppSpacing.xs) {
                Text(info.name)
                    .font(AppTypography.display)
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(info.fullVersion)
                    .font(AppTypography.callout.monospacedDigit())
                    .foregroundStyle(AppColors.textTertiary)
                    .textSelection(.enabled)
                Text(AppInfo.tagline)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.xs)
                Text("by \(Text(AppInfo.author).fontWeight(.medium).foregroundStyle(AppColors.textPrimary))")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            }
            VStack(spacing: AppSpacing.xxs) {
                AboutLink(title: "Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right",
                          tint: AppColors.Hue.purple, destination: AppInfo.repository)
                AboutLink(title: "alexandrebouttier.fr", systemImage: "globe", tint: AppColors.Hue.blue,
                          destination: AppInfo.website)
                AboutLink(title: "Report an issue", systemImage: "exclamationmark.bubble", tint: AppColors.Hue.orange,
                          destination: AppInfo.issues)
                AboutLink(title: AppInfo.license, systemImage: "doc.text", tint: AppColors.Hue.green,
                          destination: AppInfo.licenseURL)
            }
            VStack(spacing: AppSpacing.sm) {
                Text("\(AppInfo.copyright) · \(AppInfo.license)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                Button("Close") { dismiss() }
                    .appButton()
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: Self.width)
        .background(AppColors.surface)
    }
}

/// A link row of the About window: a tinted icon, a title and an arrow,
/// highlighted on hover.
private struct AboutLink: View {
    let title: String
    let systemImage: String
    let tint: Color
    let destination: URL
    @State private var isHovered = false

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: AppLayout.rowIconWidth)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "arrow.up.right")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
            .font(AppTypography.body)
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: AppLayout.rowHeight + AppSpacing.xs)
            .background(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(isHovered ? AppColors.hover : .clear))
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
        .help(destination.absoluteString)
        .accessibilityHint("Opens \(destination.absoluteString) in your browser")
    }
}
