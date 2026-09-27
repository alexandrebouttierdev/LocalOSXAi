import Foundation
import Testing
@testable import LocalOSXAi

/// The command palette and command shortcuts.
@MainActor
@Suite("Workspace command palette", .timeLimit(.minutes(1)))
struct WorkspacePaletteTests {
    private func makeWorkspace(
        models: [AIModel] = [Fixtures.model("m", capabilities: [.tools])]
    ) -> WorkspaceViewModel {
        WorkspaceViewModel(
            projects: ProjectsViewModel(service: ProjectService(repository: InMemoryProjectRepository())),
            sessions: SessionsViewModel(service: SessionService(repository: InMemorySessionRepository())),
            models: ModelsViewModel(registry: ProviderRegistry(providers: [
                MockLLMProvider(id: "fake", displayName: "Fake", models: .success(models))
            ])),
            services: .stub()
        )
    }

    @Test("the command palette lists every command with its shortcut and state")
    func paletteCommands() async {
        let workspace = makeWorkspace()
        await workspace.load()

        workspace.showCommandPalette()

        #expect(workspace.isCommandPalettePresented)
        let item = workspace.palette.results.first { $0.id == WorkspaceCommand.openProject.rawValue }
        #expect(item?.shortcut == "⌘O")
        let disabled = workspace.palette.results.first { $0.id == WorkspaceCommand.newSession.rawValue }
        #expect(disabled?.isEnabled == false)
        #expect(workspace.palette.results.count == WorkspaceCommand.allCases.count)
    }

    @Test("activating a command runs it and closes the palette")
    func activateCommand() async throws {
        let workspace = makeWorkspace()
        await workspace.load()
        workspace.showCommandPalette()
        let item = try #require(workspace.palette.results.first { $0.id == WorkspaceCommand.toggleInspector.rawValue })

        workspace.activatePaletteItem(item)

        #expect(!workspace.isCommandPalettePresented)
        #expect(!workspace.isInspectorPresented)
    }

    @Test("change model switches the palette to a model list, then selects")
    func changeModelFlow() async throws {
        let workspace = makeWorkspace(models: [Fixtures.model("alpha", capabilities: [.tools]), Fixtures.model("beta")])
        await workspace.load()
        workspace.showCommandPalette()
        let changeModel = try #require(workspace.palette.results.first { $0.id == WorkspaceCommand.changeModel.rawValue })

        workspace.activatePaletteItem(changeModel)
        #expect(workspace.isCommandPalettePresented)
        #expect(workspace.palette.results.map(\.title) == ["alpha", "beta"])
        #expect(workspace.palette.results.first?.subtitle == "Current")

        let beta = try #require(workspace.palette.results.last)
        workspace.activatePaletteItem(beta)
        #expect(!workspace.isCommandPalettePresented)
        #expect(workspace.models.selectedModel?.name == "beta")
    }
}

@Suite("CommandShortcut")
struct CommandShortcutTests {
    @Test("modifiers are displayed in macOS order")
    func displayOrder() {
        #expect(CommandShortcut("s", modifiers: [.command, .control]).displayString == "⌃⌘S")
        #expect(CommandShortcut("i", modifiers: [.command, .option]).displayString == "⌥⌘I")
        #expect(CommandShortcut("k").displayString == "⌘K")
    }

    @Test("every command shortcut is unique")
    func uniqueShortcuts() {
        let shortcuts = WorkspaceCommand.allCases.compactMap(\.shortcut)
        #expect(Set(shortcuts).count == shortcuts.count)
    }
}
