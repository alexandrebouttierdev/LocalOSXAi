import SwiftUI

/// The central column: the selected tab on a panel inset in the window
/// ground (the Linear layout). The title and the tabs live in the window
/// toolbar (`WorkspaceView`), so there is a single header row.
struct MainContentView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void

    var body: some View {
        Group {
            if viewModel.selectedProject != nil {
                tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                        .strokeBorder(AppColors.hairline, lineWidth: AppBorders.hairline)
                )
                .padding([.bottom, .trailing], AppSpacing.sm)
                .padding(.leading, AppSpacing.xxs)
                .padding(.top, AppSpacing.xs)
            } else {
                WelcomeView(viewModel: viewModel, onCommand: onCommand)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .agent:
            if let agent = viewModel.activeAgent {
                AgentView(viewModel: agent, modelName: modelName)
                    .id(agent.sessionID)
            } else {
                EmptyStateView(
                    systemImage: "square.and.pencil",
                    title: "No session selected",
                    message: "Start a session to ask the agent about this project."
                ) {
                    Button("New Session") { onCommand(.newSession) }
                        .appGlassButton(prominent: true)
                        .controlSize(.large)
                }
            }
        case .files:
            if let files = viewModel.activePanels?.files { FilesView(viewModel: files).id(files.projectRoot) }
        case .changes:
            if let changes = viewModel.activePanels?.changes { ChangesView(viewModel: changes).id(changes.projectRoot) }
        case .terminal:
            if let terminal = viewModel.activePanels?.terminal { TerminalView(viewModel: terminal).id(terminal.projectRoot) }
        }
    }

    private var modelName: String? {
        guard let model = viewModel.models.selectedModel else { return nil }
        return "\(viewModel.models.providerName(for: model.provider)) · \(model.displayName)"
    }
}
