import SwiftUI

/// Typography tokens: Inter, Linear's typeface, at Linear's sizes.
///
/// Inter Variable is bundled (App/Resources/Fonts, SIL Open Font License) and
/// registered by `ATSApplicationFontsPath` in Info.plist. Its optical size
/// axis gives display sizes Inter Display's tighter shapes automatically. If
/// the font ever fails to load, SwiftUI falls back to the system font at the
/// same size, so layout never breaks. Each size scales with the text style it
/// is relative to. 13 pt body is the density target of the interface.
enum AppTypography {
    /// Family name of the bundled variable font.
    static let family = "Inter Variable"

    /// Hero titles of empty states and the welcome screen (22 pt).
    static let display = inter(22, .semibold, relativeTo: .title)
    /// Screen and panel titles (15 pt).
    static let title = inter(15, .semibold, relativeTo: .title3)
    /// Emphasized body text: row titles, message authors.
    static let headline = inter(13, .medium, relativeTo: .body)
    /// Default reading text (13 pt).
    static let body = inter(13, .regular, relativeTo: .body)
    /// Secondary information next to body text (12 pt).
    static let callout = inter(12, .regular, relativeTo: .callout)
    /// Metadata, timestamps, hints (11 pt).
    static let caption = inter(11, .regular, relativeTo: .subheadline)
    /// Sidebar and inspector section titles: small and medium, never shouted
    /// in capitals (Linear's section labels).
    static let sectionHeader = inter(11, .medium, relativeTo: .subheadline)
    /// Code, paths, commands and tool arguments: the system monospaced face,
    /// which Inter does not replace.
    static let code = Font.system(.callout, design: .monospaced)
    /// Keyboard shortcut glyphs.
    static let shortcut = inter(11, .medium, relativeTo: .caption)

    private static func inter(_ size: CGFloat, _ weight: Font.Weight, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(family, size: size, relativeTo: style).weight(weight)
    }
}
