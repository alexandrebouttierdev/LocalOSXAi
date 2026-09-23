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
    /// Floating overlays such as the command palette.
    static let overlay: CGFloat = 12
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
    static let inspectorMinWidth: CGFloat = 240
    static let inspectorIdealWidth: CGFloat = 280
    static let inspectorMaxWidth: CGFloat = 380
    static let contentMinWidth: CGFloat = 420
    static let readableWidth: CGFloat = 760
    static let commandPaletteWidth: CGFloat = 560
    static let rowHeight: CGFloat = 28
}

/// Shadow tokens. Shadows are reserved for floating layers (palette, popovers).
struct AppShadow: Sendable {
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat

    static let overlay = AppShadow(opacity: 0.28, radius: 24, y: 12)
}

extension View {
    func appShadow(_ shadow: AppShadow) -> some View {
        self.shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, x: 0, y: shadow.y)
    }
}
