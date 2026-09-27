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
/// Used sparingly: at most one per visible area. Linear's indigo fill with a
/// faint inner edge.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration)
    }

    private struct PrimaryButton: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: AppLayout.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(AppColors.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : (isHovered ? 0.9 : 1)) : 0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: AppBorders.hairline)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .onHover { isHovered = $0 }
                .appAnimation(AppAnimation.quick, value: isHovered)
        }
    }
}

/// A normal-emphasis action next to a primary one (Deny, Retry, Revert):
/// Linear's raised neutral button with a hairline border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SecondaryButton(configuration: configuration)
    }

    private struct SecondaryButton: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(isEnabled ? AppColors.textPrimary : AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: AppLayout.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(AppColors.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .fill(configuration.isPressed ? AppColors.selection : (isHovered && isEnabled ? AppColors.hover : .clear))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .strokeBorder(isHovered && isEnabled ? AppColors.borderStrong : AppColors.border, lineWidth: AppBorders.hairline)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .onHover { isHovered = $0 }
                .appAnimation(AppAnimation.quick, value: isHovered)
        }
    }
}

/// A square button holding one symbol (send, stop): primary or secondary.
struct IconButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        IconButton(configuration: configuration, prominent: prominent)
    }

    private struct IconButton: View {
        let configuration: Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(prominent ? Color.white : (isEnabled ? AppColors.textPrimary : AppColors.textTertiary))
                .frame(width: AppLayout.buttonHeight, height: AppLayout.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .strokeBorder(prominent ? Color.white.opacity(0.12) : AppColors.border, lineWidth: AppBorders.hairline)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .onHover { isHovered = $0 }
                .appAnimation(AppAnimation.quick, value: isHovered)
        }

        private var fill: Color {
            if prominent {
                return AppColors.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : (isHovered ? 0.9 : 1)) : 0.35)
            }
            return configuration.isPressed ? AppColors.selection : (isHovered && isEnabled ? AppColors.hover : AppColors.surfaceRaised)
        }
    }
}

extension ButtonStyle where Self == SubtleButtonStyle {
    static var subtle: SubtleButtonStyle { SubtleButtonStyle() }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == IconButtonStyle {
    static func icon(prominent: Bool = false) -> IconButtonStyle { IconButtonStyle(prominent: prominent) }
}
