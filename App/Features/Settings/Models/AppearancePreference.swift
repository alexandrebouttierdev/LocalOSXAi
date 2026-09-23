import AppKit

/// The user's appearance choice, stored in `UserDefaults` (it is a UI
/// preference, not sensitive data).
enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Applied to `NSApp.appearance`. Using AppKit rather than
    /// `preferredColorScheme` makes switching back to “System” reliable.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
