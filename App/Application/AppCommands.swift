import SwiftUI

/// Menu bar commands. Every item comes from `WorkspaceCommand`, so titles,
/// shortcuts and enabled state match the command palette exactly.
struct AppCommands: Commands {
    let workspace: WorkspaceViewModel

    var body: some Commands {
        // Settings… (⌘,) opens the settings screen of the main window: the app
        // has no separate Settings window (ADR 0024).
        CommandGroup(replacing: .appInfo) {
            Button("About LocalOSXAi") { workspace.perform(.about) }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { workspace.perform(.openSettings) }
                .keyboardShortcut(WorkspaceCommand.openSettings.shortcut?.keyboardShortcut)
        }

        CommandGroup(replacing: .newItem) {
            button(.newSession)
            button(.openProject)
            Divider()
            button(.projectSettings)
        }

        CommandGroup(replacing: .sidebar) {
            button(.toggleSidebar)
            button(.toggleInspector)
            Divider()
            Button("Command Palette…") { workspace.showCommandPalette() }
                .keyboardShortcut("k", modifiers: .command)
            Divider()
        }

        CommandMenu("Go") {
            button(.showAgent)
            button(.showFiles)
            button(.showChanges)
            button(.openTerminal)
            Divider()
            button(.searchFiles)
            button(.changeModel)
            button(.compactSession)
        }
    }

    private func button(_ command: WorkspaceCommand) -> some View {
        Button(command.title) {
            workspace.perform(command)
        }
        .keyboardShortcut(command.shortcut?.keyboardShortcut)
        .disabled(!workspace.isEnabled(command))
    }
}
