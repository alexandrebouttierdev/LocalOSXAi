import Foundation

/// An entry of the command palette.
///
/// The palette knows nothing about what an item does: it only filters,
/// displays and returns the activated item's `id`. The owner of the palette
/// (the workspace) maps ids to behavior. This keeps the palette reusable and
/// independent from the main view.
struct PaletteItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    var subtitle: String?
    var systemImage: String
    /// Display form of the shortcut, e.g. “⌘O”.
    var shortcut: String?
    /// Group heading, e.g. “Navigation”.
    var section: String
    /// Extra search terms that do not appear in the title.
    var keywords: [String] = []
    var isEnabled: Bool = true
    /// Shown instead of the subtitle when the item is disabled.
    var disabledReason: String?
}
