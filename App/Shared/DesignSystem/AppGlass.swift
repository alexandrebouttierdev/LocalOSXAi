import SwiftUI

/// Glass surfaces for floating UI: command palette, composer, tab selection,
/// approval banner, cards.
///
/// On macOS 26 this is Liquid Glass (`glassEffect`), which refracts the
/// content behind it and adapts to Reduce Transparency and Increase Contrast
/// on its own. On earlier systems it falls back to a translucent material
/// with a hairline border, so the hierarchy stays the same.
///
/// Rules (docs/ui/design-system.md): glass is for layers that *float* above
/// content. Content itself (transcript, code, lists) stays on opaque
/// surfaces for legibility.
enum AppGlass {
    enum Variant {
        /// Default floating surface.
        case regular
        /// Tinted with a semantic color, for surfaces that carry a state.
        case tinted(Color)
    }
}

extension View {
    /// Applies a glass surface clipped to `shape`.
    ///
    /// - Parameter interactive: reacts to pointer interaction (buttons, chips).
    @ViewBuilder
    func appGlass<S: InsettableShape>(_ variant: AppGlass.Variant = .regular, in shape: S, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(Self.glass(variant, interactive: interactive), in: shape)
        } else {
            self
                .background(Self.fallbackTint(variant), in: shape)
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(AppColors.border, lineWidth: AppBorders.hairline))
        }
    }

    /// Identifies a glass shape so it morphs between positions (e.g. the
    /// selected tab) inside an `AppGlassContainer`. No effect before macOS 26.
    @ViewBuilder
    func appGlassID(_ id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    /// The glass button style (prominent: accent-tinted), with a fallback.
    @ViewBuilder
    func appGlassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else if prominent {
            self.buttonStyle(.primary)
        } else {
            self.buttonStyle(.subtle)
        }
    }

    @available(macOS 26, *)
    private static func glass(_ variant: AppGlass.Variant, interactive: Bool) -> Glass {
        let base: Glass = switch variant {
        case .regular: .regular
        case .tinted(let color): .regular.tint(color.opacity(0.35))
        }
        return interactive ? base.interactive() : base
    }

    private static func fallbackTint(_ variant: AppGlass.Variant) -> Color {
        switch variant {
        case .regular: .clear
        case .tinted(let color): color.opacity(0.12)
        }
    }
}

/// Groups glass shapes so they blend and morph together (macOS 26).
struct AppGlassContainer<Content: View>: View {
    var spacing: CGFloat = AppSpacing.sm
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
