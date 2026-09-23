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
    static let background = dynamic(light: 0xF7F7F8, dark: 0x0F1012)
    static let sidebar = dynamic(light: 0xF2F2F4, dark: 0x0C0D0E)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x151619)
    static let surfaceRaised = dynamic(light: 0xFFFFFF, dark: 0x1C1D21)
    static let hover = dynamic(light: 0x000000, lightAlpha: 0.04, dark: 0xFFFFFF, darkAlpha: 0.045)
    static let selection = dynamic(light: 0x000000, lightAlpha: 0.07, dark: 0xFFFFFF, darkAlpha: 0.08)
    static let scrim = dynamic(light: 0x000000, lightAlpha: 0.18, dark: 0x000000, darkAlpha: 0.45)

    // MARK: Borders
    static let border = dynamic(light: 0x000000, lightAlpha: 0.08, dark: 0xFFFFFF, darkAlpha: 0.08,
                                highContrastAlpha: 0.35)
    static let borderStrong = dynamic(light: 0x000000, lightAlpha: 0.14, dark: 0xFFFFFF, darkAlpha: 0.14,
                                      highContrastAlpha: 0.5)

    // MARK: Text
    static let textPrimary = dynamic(light: 0x1B1C1F, dark: 0xE6E7EA)
    static let textSecondary = dynamic(light: 0x5A5D66, dark: 0x9A9CA5)
    /// Lowest-emphasis text still readable at body size (≥ 4.5:1).
    static let textTertiary = dynamic(light: 0x6E717A, dark: 0x7C7F89)

    // MARK: Accent and status
    static let accent = dynamic(light: 0x5E67D1, dark: 0x7C84E6)
    static let accentSubtle = dynamic(light: 0x5E67D1, lightAlpha: 0.12, dark: 0x7C84E6, darkAlpha: 0.18)
    static let success = dynamic(light: 0x2E8A5B, dark: 0x4CB782)
    static let warning = dynamic(light: 0xA26A12, dark: 0xE0A43B)
    static let danger = dynamic(light: 0xC62F35, dark: 0xEB5A5F)

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
