import SwiftUI

/// The central column: header with breadcrumb and tabs, then the selected tab.
struct MainContentView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void

    var body: some View {
        Group {
            if let project = viewModel.selectedProject {
                VStack(spacing: 0) {
                    ContentHeaderView(
                        projectName: project.name,
                        sessionTitle: viewModel.selectedTab == .agent ? viewModel.selectedSession?.title : nil,
                        changesCount: viewModel.activePanels?.changes.changes.count ?? 0,
                        selectedTab: $viewModel.selectedTab
                    )
                    Divider().overlay(AppColors.border)
                    tabContent
                }
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

/// Breadcrumb (“Project › Session”) and the tab switcher.
private struct ContentHeaderView: View {
    let projectName: String
    let sessionTitle: String?
    let changesCount: Int
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                ProjectBadge(name: projectName)
                Text(projectName)
                    .foregroundStyle(sessionTitle == nil ? AppColors.textPrimary : AppColors.textSecondary)
                if let sessionTitle {
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .accessibilityHidden(true)
                    Text(sessionTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.opacity)
                }
            }
            .font(AppTypography.headline)
            .lineLimit(1)
            .accessibilityElement(children: .combine)

            Spacer(minLength: AppSpacing.md)

            TabSwitcher(selectedTab: $selectedTab, changesCount: changesCount)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: 52)
    }
}

/// Segmented tabs whose selection is a glass capsule that slides (and, on
/// macOS 26, morphs) from one tab to the next.
private struct TabSwitcher: View {
    @Binding var selectedTab: MainTab
    let changesCount: Int
    @Namespace private var namespace

    var body: some View {
        AppGlassContainer(spacing: 0) {
            HStack(spacing: AppSpacing.xxs) {
                ForEach(MainTab.allCases) { tab in
                    TabButton(tab: tab, isSelected: tab == selectedTab, badge: tab == .changes ? changesCount : 0, namespace: namespace) {
                        selectedTab = tab
                    }
                }
            }
            .padding(AppSpacing.xxs + 1)
            .background(AppColors.hover, in: Capsule())
        }
        .appAnimation(AppAnimation.overlay, value: selectedTab)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Views")
    }
}

private struct TabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let badge: Int
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Label(tab.title, systemImage: tab.systemImage)
                    .labelStyle(.titleAndIcon)
                if badge > 0 {
                    Text("\(badge)")
                        .font(AppTypography.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xs + 1)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(AppColors.accent, in: Capsule())
                        .accessibilityLabel("\(badge) pending")
                }
            }
                .font(AppTypography.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.textPrimary : (isHovered ? AppColors.textPrimary : AppColors.textSecondary))
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 26)
                .contentShape(Capsule())
                .background {
                    if isSelected {
                        Capsule()
                            .fill(AppColors.surfaceRaised.opacity(0.9))
                            .appGlass(in: Capsule())
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                            .appGlassID("selectedTab", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
