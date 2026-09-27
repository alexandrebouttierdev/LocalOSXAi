import SwiftUI

/// Root of the main window: sidebar, main content, inspector and the command
/// palette overlay, or the settings screen in their place. Contains layout
/// and presentation only; every action is forwarded to `WorkspaceViewModel`.
struct WorkspaceView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let agentSettings: AgentSettingsViewModel
    let providerSettings: ProviderSettingsViewModel
    @AppStorage(AppLayout.sidebarWidthKey) private var sidebarWidth = Double(AppLayout.sidebarIdealWidth)

    var body: some View {
        Group {
            if viewModel.isSettingsPresented {
                SettingsScreen(
                    section: $viewModel.settingsSection,
                    agent: agentSettings,
                    providers: providerSettings,
                    models: viewModel.models,
                    sidebarWidth: $sidebarWidth,
                    closesWithEscape: !viewModel.isCommandPalettePresented,
                    onClose: viewModel.closeSettings
                )
            } else {
                workspace
            }
        }
        // While the palette is open, VoiceOver stays inside it (modal).
        .accessibilityHidden(viewModel.isCommandPalettePresented)
        .overlay { commandPalette }
        .appAnimation(AppAnimation.overlay, value: viewModel.isCommandPalettePresented)
        .sheet(isPresented: $viewModel.isProjectSettingsPresented) {
            if let project = viewModel.selectedProject {
                ProjectSettingsView(viewModel: viewModel.projects, projectID: project.id)
            }
        }
        .fileImporter(isPresented: $viewModel.isProjectImporterPresented, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                Task { await viewModel.openProject(at: url) }
            }
        }
        .alert(
            viewModel.currentError?.title ?? "",
            isPresented: Binding(get: { viewModel.currentError != nil }, set: { if !$0 { viewModel.dismissError() } }),
            presenting: viewModel.currentError
        ) { _ in
            Button("OK", role: .cancel) { viewModel.dismissError() }
        } message: { error in
            Text([error.message, error.recoverySuggestion].compactMap { $0 }.joined(separator: "\n\n"))
        }
        .task { await viewModel.load() }
    }

    private var workspace: some View {
        SidebarLayout(isSidebarVisible: viewModel.isSidebarVisible, sidebarWidth: $sidebarWidth) {
            SidebarView(viewModel: viewModel, onCommand: handle)
        } detail: {
            MainContentView(viewModel: viewModel, onCommand: handle)
                .frame(minWidth: AppLayout.contentMinWidth)
                .inspector(isPresented: $viewModel.isInspectorPresented) {
                    InspectorView(viewModel: viewModel)
                        .inspectorColumnWidth(
                            min: AppLayout.inspectorMinWidth, ideal: AppLayout.inspectorIdealWidth, max: AppLayout.inspectorMaxWidth
                        )
                }
        }
        // The title bar is hidden; the window title still names the window
        // in the Window menu and Mission Control.
        .navigationTitle(viewModel.windowTitle)
    }

    @ViewBuilder
    private var commandPalette: some View {
        if viewModel.isCommandPalettePresented {
            ZStack(alignment: .top) {
                AppColors.scrim
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.dismissCommandPalette() }
                    .accessibilityHidden(true)
                // Esc closes the palette even when its search field lost focus.
                Button("Close Command Palette") { viewModel.dismissCommandPalette() }
                    .keyboardShortcut(.cancelAction)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                CommandPaletteView(
                    viewModel: viewModel.palette,
                    onActivate: { item in viewModel.activatePaletteItem(item) },
                    onDismiss: { viewModel.dismissCommandPalette() }
                )
                .padding(.top, 88)
                .accessibilityAddTraits(.isModal)
                .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
            }
            .transition(.opacity)
        }
    }

    private func handle(_ command: WorkspaceCommand) {
        viewModel.perform(command)
    }
}
