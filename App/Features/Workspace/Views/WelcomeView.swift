import SwiftUI

/// Shown when no project is selected: one clear action, plus recent projects.
struct WelcomeView: View {
    let viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void

    var body: some View {
        EmptyStateView(
            systemImage: "folder",
            title: "Open a project",
            message: "Choose a folder to work in. The agent can only read and change files inside the project you open."
        ) {
            VStack(spacing: AppSpacing.lg) {
                HStack(spacing: AppSpacing.sm) {
                    Button("Open Project…") { onCommand(.openProject) }
                        .buttonStyle(.primary)
                    ShortcutBadge(shortcut: WorkspaceCommand.openProject.shortcut?.displayString ?? "")
                }
                if !viewModel.projects.projects.isEmpty {
                    recentProjects
                }
            }
        }
    }

    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeader(title: "Recent projects")
            ForEach(viewModel.projects.projects.prefix(5)) { project in
                Button {
                    Task { await viewModel.selectProject(project.id) }
                } label: {
                    HStack {
                        Label(project.name, systemImage: "folder")
                        Spacer()
                        Text(project.rootURL.deletingLastPathComponent().path)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.subtle)
            }
        }
        .frame(width: 380)
    }
}
