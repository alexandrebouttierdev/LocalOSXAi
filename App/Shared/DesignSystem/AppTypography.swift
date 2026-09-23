import SwiftUI

/// Typography tokens.
///
/// Tokens map to system text styles rather than fixed point sizes so text
/// follows the platform's size settings. On macOS `.body` is 13 pt, which is
/// the density target of the interface.
enum AppTypography {
    /// Screen and panel titles (15 pt semibold).
    static let title = Font.title3.weight(.semibold)
    /// Emphasized body text: row titles, message authors.
    static let headline = Font.body.weight(.medium)
    /// Default reading text (13 pt).
    static let body = Font.body
    /// Secondary information next to body text (12 pt).
    static let callout = Font.callout
    /// Metadata, timestamps, hints (11 pt).
    static let caption = Font.subheadline
    /// Sidebar and inspector section titles.
    static let sectionHeader = Font.subheadline.weight(.semibold)
    /// Code, paths, commands and tool arguments.
    static let code = Font.system(.callout, design: .monospaced)
    /// Keyboard shortcut glyphs.
    static let shortcut = Font.system(.caption, design: .rounded).weight(.medium)
}
