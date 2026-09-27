import SwiftUI

/// Surfaces for floating UI: command palette, composer, approval banner,
/// cards, chips and the search field.
///
/// Linear's surfaces are opaque: a raised fill, a hairline border and, for
/// layers that float above content, a soft shadow. Nothing refracts or takes
/// the tint of the desktop behind the window, so contrast is the same
/// everywhere and the interface reads as one calm plane
/// (docs/decisions/0023-opaque-linear-surfaces.md, which replaced Liquid Glass).
enum AppSurface {
    enum Variant {
        /// Default floating surface.
        case regular
        /// Tinted with a semantic color, for surfaces that carry a state.
        case tinted(Color)
    }
}

extension View {
    /// An opaque raised surface clipped to `shape`.
    ///
    /// - Parameters:
    ///   - interactive: highlights on hover (chips, search field).
    ///   - elevated: casts the floating shadow; off for surfaces that sit in
    ///     the content (icons, fields).
    func appFloating<S: InsettableShape>(_ variant: AppSurface.Variant = .regular, in shape: S,
                                         interactive: Bool = false, elevated: Bool = true) -> some View {
        modifier(FloatingSurface(variant: variant, shape: shape, interactive: interactive, elevated: elevated))
    }

    /// Linear's buttons: the accent fill for the one primary action of an
    /// area, a raised neutral button otherwise.
    @ViewBuilder
    func appButton(prominent: Bool = false) -> some View {
        if prominent {
            buttonStyle(.primary)
        } else {
            buttonStyle(.secondary)
        }
    }
}

private struct FloatingSurface<S: InsettableShape>: ViewModifier {
    let variant: AppSurface.Variant
    let shape: S
    let interactive: Bool
    let elevated: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background {
                // The shadow is drawn by the fill only, never by the content.
                shape
                    .fill(AppColors.surfaceRaised)
                    .overlay { shape.fill(tint) }
                    .overlay { shape.fill(isHovered ? AppColors.hover : .clear) }
                    .shadow(color: elevated ? AppColors.shadow : .clear, radius: 16, y: 6)
            }
            .overlay { shape.strokeBorder(isHovered ? AppColors.borderStrong : AppColors.border, lineWidth: AppBorders.hairline) }
            .onHover { hovering in if interactive { isHovered = hovering } }
            .appAnimation(AppAnimation.quick, value: isHovered)
    }

    private var tint: Color {
        switch variant {
        case .regular: .clear
        case .tinted(let color): color.opacity(0.08)
        }
    }
}
