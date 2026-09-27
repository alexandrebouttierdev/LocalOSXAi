import SwiftUI

/// The central column: the selected view on a panel inset in the window
/// ground, under its own header row, like a Linear issue: the window has no
/// title bar, and the views are chosen in the sidebar.
struct MainContentView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void

    var body: some View {
        Group {
            if viewModel.selectedProject != nil {
                VStack(spacing: 0) {
                    PanelHeader(viewModel: viewModel, onCommand: onCommand)
                    Rectangle()
                        .fill(AppColors.hairline)
                        .frame(height: AppBorders.hairline)
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                        .strokeBorder(AppColors.hairline, lineWidth: AppBorders.hairline)
                )
                .padding([.bottom, .trailing], AppSpacing.sm)
                // The sidebar's resize edge already separates it from the panel.
                .padding(.leading, viewModel.isSidebarVisible ? AppSpacing.xxs : AppSpacing.sm)
                .padding(.top, AppSpacing.sm)
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
                        .appButton(prominent: true)
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

/// The panel's header row: where you are (project › session, or the view),
/// and the actions on it. Dragging it moves the window, as a title bar would.
private struct PanelHeader: View {
    let viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if !viewModel.isSidebarVisible {
                // The traffic lights float over the panel's corner.
                Color.clear.frame(width: AppLayout.windowControlsWidth - AppSpacing.md, height: 1)
                iconButton("sidebar.left", label: "Show Sidebar", command: .toggleSidebar)
            }
            Image(systemName: viewModel.selectedTab.systemImage)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textTertiary)
                .accessibilityHidden(true)
            if !viewModel.windowSubtitle.isEmpty {
                Text(viewModel.windowSubtitle)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
            Text(viewModel.windowTitle)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: AppSpacing.md)
            iconButton("sidebar.right", label: viewModel.isInspectorPresented ? "Hide Inspector" : "Show Inspector",
                       command: .toggleInspector)
        }
        .font(AppTypography.body)
        .padding(.horizontal, AppSpacing.md)
        .frame(height: AppLayout.panelHeaderHeight)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
    }

    private func iconButton(_ systemImage: String, label: String, command: WorkspaceCommand) -> some View {
        Button {
            onCommand(command)
        } label: {
            Image(systemName: systemImage)
        }
        .buttonStyle(.ghostIcon)
        .help("\(label) (\(command.shortcut?.displayString ?? ""))")
        .accessibilityLabel(label)
    }
}

