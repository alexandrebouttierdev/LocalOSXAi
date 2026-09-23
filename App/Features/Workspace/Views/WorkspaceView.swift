import SwiftUI

/// Root of the main window: sidebar, main content, inspector and the command
/// palette overlay. Contains layout and presentation only; every action is
/// forwarded to `WorkspaceViewModel`.
struct WorkspaceView: View {
    @Bindable var viewModel: WorkspaceViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView(columnVisibility: sidebarVisibility) {
            SidebarView(viewModel: viewModel, onCommand: handle)
                .navigationSplitViewColumnWidth(
                    min: AppLayout.sidebarMinWidth, ideal: AppLayout.sidebarIdealWidth, max: AppLayout.sidebarMaxWidth
                )
        } detail: {
            MainContentView(viewModel: viewModel, onCommand: handle)
                .frame(minWidth: AppLayout.contentMinWidth)
                .inspector(isPresented: $viewModel.isInspectorPresented) {
                    InspectorView(viewModel: viewModel)
                        .inspectorColumnWidth(
                            min: AppLayout.inspectorMinWidth, ideal: AppLayout.inspectorIdealWidth, max: AppLayout.inspectorMaxWidth
                        )
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            handle(.toggleInspector)
                        } label: {
                            Label("Toggle Inspector", systemImage: "sidebar.right")
                        }
                        .help("Toggle Inspector (\(WorkspaceCommand.toggleInspector.shortcut?.displayString ?? ""))")
                    }
                }
        }
        .overlay { commandPalette }
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

    private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { viewModel.isSidebarVisible ? .all : .detailOnly },
            set: { viewModel.isSidebarVisible = $0 != .detailOnly }
        )
    }

    @ViewBuilder
    private var commandPalette: some View {
        if viewModel.isCommandPalettePresented {
            ZStack(alignment: .top) {
                AppColors.scrim
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.dismissCommandPalette() }
                    .accessibilityHidden(true)
                CommandPaletteView(
                    viewModel: viewModel.palette,
                    onActivate: { item in apply(viewModel.activatePaletteItem(item)) },
                    onDismiss: { viewModel.dismissCommandPalette() }
                )
                .padding(.top, 96)
            }
            .transition(.opacity)
        }
    }

    private func handle(_ command: WorkspaceCommand) {
        apply(viewModel.perform(command))
    }

    private func apply(_ effect: WorkspaceViewModel.Effect) {
        switch effect {
        case .none: break
        case .openSettings: openSettings()
        }
    }
}
