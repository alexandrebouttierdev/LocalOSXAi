import AppKit
import SwiftUI

/// Semantic color tokens. Views use these names only, never literal colors.
///
/// Every token resolves dynamically for light, dark and Increase Contrast
/// appearances through `NSColor(name:dynamicProvider:)`, so a token keeps
/// working when the user switches appearance while the app runs. Text tokens
/// meet WCAG AA (4.5:1) against `background` and `surface` in both
/// appearances; see docs/ui/accessibility.md.
enum AppColors {
    // MARK: Surfaces
    /// The window ground, behind the sidebar and around the content panel.
    static let background = dynamic(light: 0xF4F4F5, dark: 0x0B0C0D)
    /// The content panel inset on the ground (Linear's layout).
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x111214)
    static let surfaceRaised = dynamic(light: 0xFFFFFF, dark: 0x1C1D21)
    static let hover = dynamic(light: 0x000000, lightAlpha: 0.04, dark: 0xFFFFFF, darkAlpha: 0.045)
    static let selection = dynamic(light: 0x000000, lightAlpha: 0.07, dark: 0xFFFFFF, darkAlpha: 0.08)
    static let scrim = dynamic(light: 0x000000, lightAlpha: 0.12, dark: 0x000000, darkAlpha: 0.32)

    // MARK: Borders
    /// Separators and panel outlines.
    static let hairline = dynamic(light: 0x000000, lightAlpha: 0.07, dark: 0xFFFFFF, darkAlpha: 0.06,
                                  highContrastAlpha: 0.35)
    static let border = dynamic(light: 0x000000, lightAlpha: 0.08, dark: 0xFFFFFF, darkAlpha: 0.08,
                                highContrastAlpha: 0.35)
    static let borderStrong = dynamic(light: 0x000000, lightAlpha: 0.14, dark: 0xFFFFFF, darkAlpha: 0.14,
                                      highContrastAlpha: 0.5)

    // MARK: Text
    static let textPrimary = dynamic(light: 0x1B1C1F, dark: 0xE6E7EA)
    static let textSecondary = dynamic(light: 0x5A5D66, dark: 0x9A9CA5)
    /// Lowest-emphasis text still readable at body size (≥ 4.5:1).
    static let textTertiary = dynamic(light: 0x696C75, dark: 0x7C7F89)

    // MARK: Accent and status
    /// Fills carrying white text or marks: primary button, badges, meters.
    static let accent = dynamic(light: 0x5E67D1, dark: 0x5B64CF)
    /// The accent as text or a thin glyph: readable (≥ 4.5:1) on dark surfaces,
    /// where the fill color would be too dim.
    static let accentText = dynamic(light: 0x4F58C4, dark: 0xAAB0F5)
    static let accentSubtle = dynamic(light: 0x5E67D1, lightAlpha: 0.12, dark: 0x7C84E6, darkAlpha: 0.16)
    static let success = dynamic(light: 0x2E8A5B, dark: 0x4CB782)
    static let warning = dynamic(light: 0xA26A12, dark: 0xE0A43B)
    static let danger = dynamic(light: 0xC62F35, dark: 0xEB5A5F)

    /// Stable hues identifying projects (badge fill). Muted so badges never
    /// compete with the accent or status colors.
    static let projectPalette: [Color] = [
        dynamic(light: 0x5E67D1, dark: 0x7C84E6), dynamic(light: 0x2E8A5B, dark: 0x4CB782),
        dynamic(light: 0xB35C1E, dark: 0xE08A4A), dynamic(light: 0x9C4DB8, dark: 0xB97FD6),
        dynamic(light: 0x1F7FA8, dark: 0x4BA9D6), dynamic(light: 0xB8434F, dark: 0xE06C78),
        dynamic(light: 0x8A7A1E, dark: 0xC9B24A), dynamic(light: 0x3D6E8F, dark: 0x6F9FC2)
    ]

    /// Code blocks: slightly recessed from the surface they sit on.
    static let codeBackground = dynamic(light: 0x000000, lightAlpha: 0.035, dark: 0x000000, darkAlpha: 0.28)

    // MARK: Factory

    private static func dynamic(
        light: UInt32, lightAlpha: CGFloat = 1,
        dark: UInt32, darkAlpha: CGFloat = 1,
        highContrastAlpha: CGFloat? = nil
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua
            ])
            let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let isHighContrast = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
            let alpha = isHighContrast ? (highContrastAlpha ?? (isDark ? darkAlpha : lightAlpha)) : (isDark ? darkAlpha : lightAlpha)
            return NSColor(hex: isDark ? dark : light, alpha: alpha)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
