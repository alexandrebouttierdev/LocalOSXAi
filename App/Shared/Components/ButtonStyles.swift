import SwiftUI

/// Low-emphasis button: text with a hover background. The default for most
/// actions in toolbars, headers and rows.
struct SubtleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SubtleButton(configuration: configuration)
    }

    private struct SubtleButton: View {
        let configuration: Configuration
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(AppTypography.callout)
                .foregroundStyle(isEnabled ? AppColors.textSecondary : AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.sm)
                .frame(minHeight: 24)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(configuration.isPressed ? AppColors.selection : (isHovered && isEnabled ? AppColors.hover : .clear))
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .onHover { isHovered = $0 }
                .appAnimation(AppAnimation.quick, value: isHovered)
        }
    }
}

/// The single high-emphasis action of a surface (e.g. “Send”, “Open Project”).
/// Used sparingly: at most one per visible area.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration)
    }

    private struct PrimaryButton: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: 26)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(AppColors.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4))
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
    }
}

extension ButtonStyle where Self == SubtleButtonStyle {
    static var subtle: SubtleButtonStyle { SubtleButtonStyle() }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
