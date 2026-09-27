import SwiftUI

/// Spacing scale (4 pt grid, with a 2 pt step for tight inline gaps).
enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Corner radii. Small radii keep the interface precise rather than “bubbly”.
enum AppRadius {
    /// Badges, keycaps.
    static let small: CGFloat = 4
    /// Rows, buttons, fields.
    static let medium: CGFloat = 6
    /// Panels and cards.
    static let large: CGFloat = 8
    /// The content panel inset on the window ground.
    static let panel: CGFloat = 12
    /// Floating overlays such as the command palette.
    static let overlay: CGFloat = 12
    /// User message bubbles.
    static let bubble: CGFloat = 10
    /// The floating composer and the approval banner.
    static let composer: CGFloat = 12
}

/// Border widths.
enum AppBorders {
    static let hairline: CGFloat = 1
}

/// Fixed layout dimensions shared by several views.
enum AppLayout {
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 320
    /// Where the sidebar width is remembered (`@AppStorage`, a UI preference).
    static let sidebarWidthKey = "layout.sidebarWidth"

    /// A sidebar width within the allowed range.
    static func clampedSidebarWidth(_ width: Double) -> CGFloat {
        min(max(CGFloat(width), sidebarMinWidth), sidebarMaxWidth)
    }
    static let inspectorMinWidth: CGFloat = 240
    static let inspectorIdealWidth: CGFloat = 280
    static let inspectorMaxWidth: CGFloat = 380
    static let contentMinWidth: CGFloat = 420
    static let readableWidth: CGFloat = 760
    static let commandPaletteWidth: CGFloat = 560
    /// Column of a settings page on the settings screen.
    static let settingsWidth: CGFloat = 720
    static let rowHeight: CGFloat = 28
    /// Buttons and icon buttons (Linear's compact 28 pt controls).
    static let buttonHeight: CGFloat = 28
}
