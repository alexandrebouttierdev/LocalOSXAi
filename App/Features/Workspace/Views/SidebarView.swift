import SwiftUI

/// Sidebar, laid out like Linear's: the project switcher with search and a
/// new-session button on one row, the project's views (Files, Changes,
/// Terminal), then its sessions in collapsible date sections, each with an
/// icon showing what its agent is doing. Settings and the servers below.
///
/// Flat on the window ground with neutral rows (`SidebarRow`), built from
/// plain views rather than a `List`, whose selection always takes the system
/// accent (ADR 0025). ↑/↓ move through the sessions
/// (`WorkspaceViewModel.selectAdjacentSession`).
struct SidebarView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let onCommand: (WorkspaceCommand) -> Void
    @State private var projectPendingRemoval: Project?
    /// Date sections the user folded, like Linear's collapsible sections.
    @State private var collapsedPeriods: Set<SessionGroup.Period> = []
    /// Clicking a row focuses the list, so ↑/↓ continue from there.
    @FocusState private var isListFocused: Bool

    /// The project's views besides the agent, which its sessions stand for.
    private static let views: [MainTab] = [.files, .changes, .terminal]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room for the traffic lights; dragging it moves the window.
            Color.clear
                .frame(height: AppLayout.windowControlsHeight)
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
            topRow
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if viewModel.selectedProject != nil {
                        viewRows
                    }
                    sessionSections
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
        Task { await viewModel.selectAdjacentSession(offset) }
        return .handled
    }

    // MARK: Top row

    /// Linear's “Workspace ⌄  🔍 ✎” row: the project switcher, search, new session.
    private var topRow: some View {
        HStack(spacing: AppSpacing.xxs) {
            projectSwitcher
            Spacer(minLength: AppSpacing.xs)
            Button {
                viewModel.showCommandPalette()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.ghostIcon)
            .help("Search and commands (⌘K)")
            .accessibilityLabel("Command palette")
            Button {
                onCommand(.newSession)
            } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: AppLayout.buttonHeight, height: AppLayout.buttonHeight)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .appFloating(in: Circle(), interactive: true, elevated: false)
            .disabled(!viewModel.isEnabled(.newSession))
            .help(viewModel.disabledReason(for: .newSession)
                  ?? "New session (\(WorkspaceCommand.newSession.shortcut?.displayString ?? ""))")
            .accessibilityLabel("New session")
        }
    }

    /// The current project, and every project action, in one menu.
    private var projectSwitcher: some View {
        Menu {
            ForEach(viewModel.projects.projects) { project in
                Button {
                    Task { await viewModel.selectProject(project.id) }
                } label: {
                    if project.id == viewModel.selectedProjectID {
                        Label(project.name, systemImage: "checkmark")
                    } else {
                        Text(project.name)
                    }
                }
            }
            if !viewModel.projects.projects.isEmpty { Divider() }
            Button("Open Project…") { onCommand(.openProject) }
            if let project = viewModel.selectedProject {
                Button("Project Settings…") {
                    Task { await viewModel.showProjectSettings(for: project.id) }
                }
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.rootURL]) }
                Divider()
                Button("Remove “\(project.name)” from List…", role: .destructive) {
                    projectPendingRemoval = project
                }
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if let project = viewModel.selectedProject {
                    ProjectBadge(name: project.name, size: 20)
                    Text(project.name)
                        .lineLimit(1)
                } else {
                    Image(systemName: "sparkle")
                        .font(AppTypography.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .accessibilityHidden(true)
                    Text("LocalOSXAi")
                }
                Image(systemName: "chevron.down")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
            .frame(height: AppLayout.rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help(viewModel.selectedProject?.rootURL.path ?? "Open a project folder")
        .accessibilityLabel("Project")
        .accessibilityValue(viewModel.selectedProject?.name ?? "None")
    }

    // MARK: Views

    private var viewRows: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Self.views) { tab in
                SidebarRow(isSelected: viewModel.selectedTab == tab, action: { viewModel.selectedTab = tab }) {
                    HStack(spacing: AppSpacing.sm) {
                        SidebarIcon(systemImage: tab.systemImage, tint: Self.tint(for: tab))
                        Text(tab.title)
                        Spacer(minLength: AppSpacing.xs)
                        if tab == .changes, viewModel.pendingChangesCount > 0 {
                            Text("\(viewModel.pendingChangesCount)")
                                .font(AppTypography.caption.monospacedDigit().weight(.medium))
                                .foregroundStyle(AppColors.Hue.orange)
                                .accessibilityLabel("\(viewModel.pendingChangesCount) pending")
                        }
                    }
                }
            }
        }
    }

    // MARK: Sessions

    @ViewBuilder
    private var sessionSections: some View {
        if viewModel.selectedProject == nil {
            placeholder(viewModel.projects.projects.isEmpty ? "Open a project folder to start a session."
                                                           : "Choose a project above.")
        } else if viewModel.sessions.sessions.isEmpty {
            placeholder("No sessions yet. Start one with ✎ or ⌘N.")
        } else {
            // Recomputed with the list, so “Today” rolls over on the next change.
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(viewModel.sessionGroups(now: .now)) { group in
                    let isCollapsed = collapsedPeriods.contains(group.period)
                    VStack(alignment: .leading, spacing: 1) {
                        SidebarSectionHeader(title: group.period.title, isCollapsed: isCollapsed) {
                            collapsedPeriods.formSymmetricDifference([group.period])
                        }
                        if !isCollapsed {
                            ForEach(group.sessions) { session in
                                sessionRow(session)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        let isSelected = viewModel.selectedTab == .agent && session.id == viewModel.selectedSessionID
        return SidebarRow(isSelected: isSelected, action: {
            isListFocused = true
            Task { await viewModel.selectSession(session.id) }
        }) {
            SessionRowLabel(session: session, activity: viewModel.activity(of: session.id))
        }
        .contextMenu {
            Button("Delete Session", role: .destructive) {
                Task { await viewModel.sessions.delete(session.id) }
            }
        }
    }

    /// Each view keeps its hue, like Linear's colored sidebar icons.
    private static func tint(for tab: MainTab) -> Color {
        switch tab {
        case .files: AppColors.Hue.blue
        case .changes: AppColors.Hue.orange
        case .terminal: AppColors.Hue.teal
        default: AppColors.textSecondary
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.callout)
            .foregroundStyle(AppColors.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppSpacing.sm)
    }

    // MARK: Chrome

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
    }

    /// Which model servers answered, in words; the logos and the dot (green
    /// when one answered, red otherwise) are decoration only.
    @ViewBuilder
    private var connectionStatus: some View {
        let connected = viewModel.models.connectedProviders
        if !viewModel.models.catalog.isEmpty {
            HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                StatusDot(color: connected.isEmpty ? AppColors.danger : AppColors.success)
                if !connected.isEmpty {
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
}
