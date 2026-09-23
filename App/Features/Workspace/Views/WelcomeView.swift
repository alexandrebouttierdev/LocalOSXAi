import SwiftUI

/// Shown when no project is selected: the app's mark, one clear action, and
/// recent projects.
struct WelcomeView: View {
    let viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            VStack(spacing: AppSpacing.lg) {
                AgentAvatar(size: 64)
                VStack(spacing: AppSpacing.xs) {
                    Text("LocalOSXAi")
                        .font(AppTypography.display)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("A coding agent that runs on your Mac, with your local models.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                Button {
                    onCommand(.openProject)
                } label: {
                    Label("Open Project…", systemImage: "folder.badge.plus")
                        .padding(.horizontal, AppSpacing.xs)
                }
                .appGlassButton(prominent: true)
                .controlSize(.large)
                ShortcutBadge(shortcut: WorkspaceCommand.openProject.shortcut?.displayString ?? "")
            }

            if !viewModel.projects.projects.isEmpty {
                recentProjects
            }

            Text("The agent can only read and change files inside the project you open.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Recent")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)
                .accessibilityAddTraits(.isHeader)
            ForEach(viewModel.projects.projects.prefix(5)) { project in
                RecentProjectRow(project: project) {
                    Task { await viewModel.selectProject(project.id) }
                }
            }
        }
        .padding(AppSpacing.sm)
        .frame(width: 420)
        .appGlass(in: RoundedRectangle(cornerRadius: AppRadius.overlay, style: .continuous))
    }
}

private struct RecentProjectRow: View {
    let project: Project
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ProjectBadge(name: project.name, size: 24)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(project.name)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(project.rootURL.deletingLastPathComponent().path)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: 44)
            .background(isHovered ? AppColors.hover : .clear, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
        .accessibilityLabel("Open \(project.name)")
    }
}
