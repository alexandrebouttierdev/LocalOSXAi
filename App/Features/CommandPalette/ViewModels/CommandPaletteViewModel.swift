import Foundation
import Observation

/// Filtering, ranking and keyboard selection for the command palette.
///
/// Items are supplied by the owner through `show(items:placeholder:)`. The
/// palette can be re-populated while open (e.g. “Change Model…” replaces the
/// commands with a model list), which resets the query and selection.
@MainActor
@Observable
final class CommandPaletteViewModel {
    var query = "" {
        didSet { recomputeResults() }
    }
    private(set) var results: [PaletteItem] = []
    private(set) var selectedIndex = 0
    private(set) var placeholder = "Type a command or search…"

    private var items: [PaletteItem] = []

    var selectedItem: PaletteItem? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    func show(items: [PaletteItem], placeholder: String) {
        self.items = items
        self.placeholder = placeholder
        query = ""
        recomputeResults()
    }

    /// Moves the highlighted row, wrapping around at both ends.
    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + offset % results.count + results.count) % results.count
    }

    func select(_ item: PaletteItem) {
        if let index = results.firstIndex(of: item) { selectedIndex = index }
    }

    /// Returns the highlighted item if it can be activated.
    func activateSelection() -> PaletteItem? {
        guard let selectedItem, selectedItem.isEnabled else { return nil }
        return selectedItem
    }

    /// Section headings are meaningful only for the unfiltered, grouped list.
    /// Ranked search results interleave sections, so they are shown flat.
    var showsSections: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Empty query: items in their original, grouped order, with the first
    /// enabled item highlighted. Otherwise: matching items by descending
    /// score, ties keeping original order.
    private func recomputeResults() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = items
            selectedIndex = items.firstIndex { $0.isEnabled } ?? 0
            return
        }
        defer { selectedIndex = 0 }

        var ranked: [RankedItem] = []
        for (order, item) in items.enumerated() {
            guard let score = FuzzyMatcher.bestScore(trimmed, in: [item.title] + item.keywords) else { continue }
            // Disabled items stay findable but always rank below enabled ones.
            ranked.append(RankedItem(item: item, score: item.isEnabled ? score : score - 1_000, order: order))
        }
        ranked.sort { lhs, rhs in lhs.score != rhs.score ? lhs.score > rhs.score : lhs.order < rhs.order }
        results = ranked.map { $0.item }
    }

    private struct RankedItem {
        let item: PaletteItem
        let score: Int
        let order: Int
    }
}
