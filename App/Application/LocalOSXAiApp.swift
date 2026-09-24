import SwiftUI

/// The application: one main window, the Settings window and menu commands.
///
/// A single `Window` (not a `WindowGroup`) is used on purpose: one workspace
/// per app avoids two windows driving the same session concurrently. Multiple
/// windows are a later decision (docs/ui/navigation.md).
struct LocalOSXAiApp: App {
    @State private var workspace: WorkspaceViewModel
    @State private var providerSettings: ProviderSettingsViewModel
    @State private var agentSettings: AgentSettingsViewModel
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    init() {
        let environment = AppEnvironment.current()
        let workspace = environment.makeWorkspaceViewModel()
        _workspace = State(initialValue: workspace)
        _providerSettings = State(initialValue: environment.makeProviderSettingsViewModel(models: workspace.models))
        _agentSettings = State(initialValue: environment.makeAgentSettingsViewModel())
    }

    var body: some Scene {
        Window("LocalOSXAi", id: "main") {
            WorkspaceView(viewModel: workspace)
                .frame(minWidth: 900, minHeight: 560)
                .onChange(of: appearance, initial: true) {
                    NSApp.appearance = appearance.nsAppearance
                }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 820)
        .commands {
            AppCommands(workspace: workspace)
        }

        Settings {
            SettingsView(agent: agentSettings, providers: providerSettings, models: workspace.models)
        }
    }
}
