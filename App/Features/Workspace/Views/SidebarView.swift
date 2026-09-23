import SwiftUI

/// Sidebar: command palette entry point, projects, sessions of the selected
/// project, recent sessions elsewhere, and settings.
///
/// Uses a native `List` so keyboard navigation, type-select and VoiceOver
/// work out of the box; styling stays restrained to fit the Linear-like look.
struct SidebarView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void

    var body: some View {
        List(selection: selection) {
            projectsSection
            if viewModel.selectedProject != nil {
                sessionsSection
            }
            if !viewModel.sessions.recentSessions.isEmpty {
                recentSection
            }
        }
        // Native sidebar material: Liquid Glass on macOS 26, vibrancy before.
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) { searchButton }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var selection: Binding<WorkspaceViewModel.SidebarItem?> {
        Binding(
            get: { viewModel.sidebarSelection },
            set: { item in Task { await viewModel.select(item) } }
        )
    }

    // MARK: Sections

    private var projectsSection: some View {
        Section {
            if viewModel.projects.projects.isEmpty {
                Text("No projects yet")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
                    .selectionDisabled()
            }
            ForEach(viewModel.projects.projects) { project in
                Label {
                    Text(project.name)
                        .fontWeight(project.id == viewModel.selectedProjectID ? .semibold : .regular)
                } icon: {
                    ProjectBadge(name: project.name, size: 16)
                }
                .help(project.rootURL.path)
                    .tag(WorkspaceViewModel.SidebarItem.project(project.id))
                    .contextMenu {
                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.rootURL]) }
                        Divider()
                        Button("Remove from List", role: .destructive) {
                            Task { await viewModel.projects.remove(project.id) }
                        }
                    }
            }
        } header: {
            SectionHeader(title: "Projects") {
                addButton("Open Project…", command: .openProject)
            }
        }
    }

    private var sessionsSection: some View {
        Section {
            if viewModel.sessions.sessions.isEmpty {
                Text("No sessions yet")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
                    .selectionDisabled()
            }
            ForEach(viewModel.sessions.sessions) { session in
                SessionRow(session: session, subtitle: nil)
                    .tag(WorkspaceViewModel.SidebarItem.session(session.id))
                    .contextMenu {
                        Button("Delete Session", role: .destructive) {
                            Task { await viewModel.sessions.delete(session.id) }
                        }
                    }
            }
        } header: {
            SectionHeader(title: "Sessions") {
                addButton("New Session", command: .newSession)
            }
        }
    }

    private var recentSection: some View {
        Section {
            ForEach(viewModel.sessions.recentSessions) { session in
                SessionRow(session: session, subtitle: viewModel.projects.project(id: session.projectID)?.name)
                    .tag(WorkspaceViewModel.SidebarItem.session(session.id))
            }
        } header: {
            SectionHeader(title: "Recent")
        }
    }

    // MARK: Chrome

    private var searchButton: some View {
        Button {
            viewModel.showCommandPalette()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)
                Text("Search or run a command")
                Spacer(minLength: AppSpacing.xs)
                ShortcutBadge(shortcut: "⌘K")
            }
            .font(AppTypography.callout)
            .foregroundStyle(AppColors.textTertiary)
            .padding(.leading, AppSpacing.md)
            .padding(.trailing, AppSpacing.xs + AppSpacing.xxs)
            .frame(height: 30)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .appGlass(in: Capsule(), interactive: true)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityLabel("Command palette")
        .accessibilityHint("Shortcut Command K")
    }

    private var footer: some View {
        HStack(spacing: AppSpacing.sm) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.subtle)
            Spacer()
            if viewModel.isSimulated {
                StatusBadge(title: "Simulated", systemImage: "theatermasks", tone: .warning)
                    .help("Simulated mode (LOCALOSXAI_SIMULATED=1): no model server is called and no file is read.")
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .overlay(alignment: .top) { Divider().overlay(AppColors.border) }
    }

    private func addButton(_ title: String, command: WorkspaceCommand) -> some View {
        Button {
            onCommand(command)
        } label: {
            Image(systemName: "plus")
                .font(AppTypography.caption.weight(.semibold))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColors.textTertiary)
        .help(title)
        .accessibilityLabel(title)
        .disabled(!viewModel.isEnabled(command))
    }
}

private struct SessionRow: View {
    let session: Session
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(session.title)
                .lineLimit(1)
            HStack(spacing: AppSpacing.xs) {
                if let subtitle {
                    Text(subtitle)
                        .lineLimit(1)
                    Text("·")
                }
                Text(session.updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.vertical, AppSpacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
