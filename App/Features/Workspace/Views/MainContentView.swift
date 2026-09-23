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
                        sessionTitle: viewModel.selectedSession?.title,
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
                        .buttonStyle(.primary)
                }
            }
        case .files, .changes, .terminal:
            let tab = viewModel.selectedTab
            EmptyStateView(
                systemImage: tab.systemImage,
                title: "\(tab.title) — coming in Phase \(tab.plannedPhase ?? 0)",
                message: tab.placeholderMessage
            )
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
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                Text(projectName)
                    .foregroundStyle(sessionTitle == nil ? AppColors.textPrimary : AppColors.textSecondary)
                if let sessionTitle {
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .accessibilityHidden(true)
                    Text(sessionTitle)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .font(AppTypography.headline)
            .lineLimit(1)
            .accessibilityElement(children: .combine)

            Spacer(minLength: AppSpacing.md)

            HStack(spacing: AppSpacing.xxs) {
                ForEach(MainTab.allCases) { tab in
                    TabButton(tab: tab, isSelected: tab == selectedTab) { selectedTab = tab }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: 44)
    }
}

private struct TabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(tab.title, systemImage: tab.systemImage)
                .labelStyle(.titleAndIcon)
                .font(AppTypography.callout.weight(isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(isSelected ? AppColors.selection : (isHovered ? AppColors.hover : .clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
