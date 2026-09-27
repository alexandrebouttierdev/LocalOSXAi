import SwiftUI

/// Sidebar: command palette entry point, projects, sessions of the selected
/// project, recent sessions elsewhere, and settings.
///
/// Linear's sidebar: flat on the window ground, rows with a neutral
/// selection (`SidebarRow`). Built from plain views rather than a `List`,
/// whose selection always takes the system accent; ↑/↓ still move the
/// selection (`WorkspaceViewModel.selectAdjacentSidebarItem`), and every row
/// is a labelled button for VoiceOver.
struct SidebarView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void
    @State private var projectPendingRemoval: Project?
    /// Clicking a row focuses the list, so ↑/↓ continue from there.
    @FocusState private var isListFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                appHeader
                searchButton
            }
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    projectsSection
                    if viewModel.selectedProject != nil {
                        sessionsSection
                    }
                    if !viewModel.sessions.recentSessions.isEmpty {
                        recentSection
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
            }
            .scrollIndicators(.never)
            .focusable()
            .focused($isListFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { move(-1) }
            .onKeyPress(.downArrow) { move(1) }
            footer
        }
        .background(AppColors.background)
        .confirmationDialog(
            "Remove “\(projectPendingRemoval?.name ?? "")” from the list?",
            isPresented: Binding(get: { projectPendingRemoval != nil }, set: { if !$0 { projectPendingRemoval = nil } }),
            presenting: projectPendingRemoval
        ) { project in
            Button("Remove Project and Sessions", role: .destructive) {
                Task { await viewModel.removeProject(project.id) }
            }
        } message: { _ in
            Text("Its sessions are deleted from LocalOSXAi. The folder and its files on disk are not touched.")
        }
    }

    private func move(_ offset: Int) -> KeyPress.Result {
        Task { await viewModel.selectAdjacentSidebarItem(offset) }
        return .handled
    }

    private func select(_ item: WorkspaceViewModel.SidebarItem) {
        isListFocused = true
        Task { await viewModel.select(item) }
    }

    // MARK: Sections

    private var projectsSection: some View {
        SidebarSection {
            SectionHeader(title: "Projects") {
                addButton("Open Project…", command: .openProject)
            }
        } content: {
            if viewModel.projects.projects.isEmpty {
                placeholder("No projects yet")
            }
            ForEach(viewModel.projects.projects) { project in
                let item = WorkspaceViewModel.SidebarItem.project(project.id)
                SidebarRow(isSelected: viewModel.sidebarSelection == item, action: { select(item) }) {
                    Label {
                        Text(project.name)
                            .fontWeight(project.id == viewModel.selectedProjectID ? .semibold : .regular)
                            .lineLimit(1)
                    } icon: {
                        ProjectBadge(name: project.name, size: 16)
                    }
                }
                .help(project.rootURL.path)
                .contextMenu {
                    Button("Project Settings…") {
                        Task { await viewModel.showProjectSettings(for: project.id) }
                    }
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.rootURL]) }
                    Divider()
                    Button("Remove from List…", role: .destructive) {
                        projectPendingRemoval = project
                    }
                }
            }
        }
    }

    private var sessionsSection: some View {
        SidebarSection {
            SectionHeader(title: "Sessions") {
                addButton("New Session", command: .newSession)
            }
        } content: {
            if viewModel.sessions.sessions.isEmpty {
                placeholder("No sessions yet")
            }
            ForEach(viewModel.sessions.sessions) { session in
                sessionRow(session, subtitle: nil, showsToolCalls: true)
                    .contextMenu {
                        Button("Delete Session", role: .destructive) {
                            Task { await viewModel.sessions.delete(session.id) }
                        }
                    }
            }
        }
    }

    private var recentSection: some View {
        SidebarSection {
            SectionHeader(title: "Recent")
        } content: {
            ForEach(viewModel.sessions.recentSessions) { session in
                sessionRow(session, subtitle: viewModel.projects.project(id: session.projectID)?.name, showsToolCalls: false)
            }
        }
    }

    private func sessionRow(_ session: Session, subtitle: String?, showsToolCalls: Bool) -> some View {
        let item = WorkspaceViewModel.SidebarItem.session(session.id)
        return SidebarRow(isSelected: viewModel.sidebarSelection == item, action: { select(item) }) {
            SessionRow(session: session, subtitle: subtitle, showsToolCalls: showsToolCalls)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.callout)
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, AppSpacing.sm)
            .frame(minHeight: AppLayout.rowHeight)
    }

    // MARK: Chrome

    private var appHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .accessibilityHidden(true)
            Text("LocalOSXAi")
                .font(AppTypography.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.md + AppSpacing.xxs)
        .padding(.top, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var searchButton: some View {
        Button {
            viewModel.showCommandPalette()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)
                // Short on purpose: the sidebar can be narrow, and this label
                // must stay on one line.
                Text("Search")
                    .lineLimit(1)
                Spacer(minLength: AppSpacing.xs)
                ShortcutBadge(shortcut: "⌘K")
            }
            .font(AppTypography.callout)
            .foregroundStyle(AppColors.textTertiary)
            .padding(.leading, AppSpacing.md)
            .padding(.trailing, AppSpacing.xs + AppSpacing.xxs)
            .frame(height: AppLayout.buttonHeight)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .appFloating(in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous), interactive: true, elevated: false)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityLabel("Command palette")
        .accessibilityHint("Shortcut Command K")
    }

    private var footer: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                onCommand(.openSettings)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.subtle)
            .help("Settings (⌘,)")
            Spacer()
            if viewModel.isSimulated {
                StatusBadge(title: "Simulated", systemImage: "theatermasks", tone: .warning)
                    .help("Simulated mode (LOCALOSXAI_SIMULATED=1): no model server is called and no file is read.")
            } else {
                connectionStatus
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .overlay(alignment: .top) { Divider().overlay(AppColors.border) }
    }

    /// Which model servers answered, in words; the logos and the red dot are
    /// decoration only.
    @ViewBuilder
    private var connectionStatus: some View {
        let connected = viewModel.models.connectedProviders
        if !viewModel.models.catalog.isEmpty {
            HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                if connected.isEmpty {
                    Circle()
                        .fill(AppColors.danger)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                } else {
                    HStack(spacing: AppSpacing.xxs + 1) {
                        ForEach(connected) { provider in
                            ProviderLogo(asset: provider.logo, size: 12)
                        }
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
                Text(connected.isEmpty ? "No model server"
                                       : "\(connected.map(\.displayName).joined(separator: ", ")) connected")
                    .lineLimit(1)
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textTertiary)
            .help(connected.isEmpty ? "Start Ollama or LM Studio, then refresh the models." : "Model servers that answered.")
        }
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
    let showsToolCalls: Bool

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
                if showsToolCalls, session.toolCallCount > 0 {
                    Text("·")
                    Text(session.toolCallCount == 1 ? "1 tool call" : "\(session.toolCallCount) tool calls")
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.vertical, AppSpacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

/// A titled group of sidebar rows.
private struct SidebarSection<Header: View, Content: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            header
                .padding(.horizontal, AppSpacing.sm)
            content
        }
    }
}
