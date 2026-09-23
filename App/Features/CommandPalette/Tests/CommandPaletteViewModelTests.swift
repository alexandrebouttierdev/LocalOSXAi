import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("CommandPaletteViewModel")
struct CommandPaletteViewModelTests {
    private let items = [
        PaletteItem(id: "open", title: "Open Project…", systemImage: "folder", section: "Project"),
        PaletteItem(id: "search", title: "Search Files…", systemImage: "doc", section: "Project",
                    isEnabled: false, disabledReason: "Later"),
        PaletteItem(id: "new", title: "New Session", systemImage: "plus", section: "Project", keywords: ["chat"]),
        PaletteItem(id: "terminal", title: "Open Terminal", systemImage: "terminal", section: "Navigation")
    ]

    private func makeViewModel() -> CommandPaletteViewModel {
        let viewModel = CommandPaletteViewModel()
        viewModel.show(items: items, placeholder: "Search")
        return viewModel
    }

    @Test("an empty query lists items in their original, grouped order with sections")
    func emptyQuery() {
        let viewModel = makeViewModel()
        #expect(viewModel.results.map(\.id) == ["open", "search", "new", "terminal"])
        #expect(viewModel.selectedItem?.id == "open")
        #expect(viewModel.showsSections)
    }

    @Test("the first enabled item is highlighted initially")
    func firstEnabledSelected() {
        let viewModel = CommandPaletteViewModel()
        viewModel.show(items: Array(items[1...]), placeholder: "Search")
        #expect(viewModel.selectedItem?.id == "new")
    }

    @Test("typing filters and ranks results, resetting the selection")
    func filtering() {
        let viewModel = makeViewModel()
        viewModel.moveSelection(by: 2)
        viewModel.query = "term"
        #expect(viewModel.results.map(\.id) == ["terminal"])
        #expect(viewModel.selectedIndex == 0)
        #expect(!viewModel.showsSections)
    }

    @Test("keywords are searchable")
    func keywords() {
        let viewModel = makeViewModel()
        viewModel.query = "chat"
        #expect(viewModel.results.first?.id == "new")
    }

    @Test("disabled items remain findable but rank last and cannot be activated")
    func disabledItems() {
        let viewModel = makeViewModel()
        viewModel.query = "s"
        #expect(viewModel.results.last?.id == "search")

        viewModel.query = "search files"
        #expect(viewModel.selectedItem?.id == "search")
        #expect(viewModel.activateSelection() == nil)
    }

    @Test("selection wraps around in both directions")
    func wrapping() {
        let viewModel = makeViewModel()
        viewModel.moveSelection(by: -1)
        #expect(viewModel.selectedItem?.id == "terminal")
        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedItem?.id == "open")
        viewModel.moveSelection(by: 5)
        #expect(viewModel.selectedItem?.id == "search")
    }

    @Test("moving the selection with no results does nothing")
    func noResults() {
        let viewModel = makeViewModel()
        viewModel.query = "zzzz"
        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedItem == nil)
        #expect(viewModel.activateSelection() == nil)
    }

    @Test("showing new items resets the query")
    func showResets() {
        let viewModel = makeViewModel()
        viewModel.query = "open"
        viewModel.show(items: [items[0]], placeholder: "Choose a model…")
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.placeholder == "Choose a model…")
        #expect(viewModel.results.count == 1)
    }
}
