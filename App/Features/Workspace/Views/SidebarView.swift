import SwiftUI

/// Sidebar, laid out like Claude Code's: New session, search, the project
/// switcher, then the project's sessions as one-line rows grouped by date,
/// each with what its agent is doing; Settings and the model servers below.
///
/// Flat on the window ground with neutral rows (`SidebarRow`), built from
/// plain views rather than a `List`, whose selection always takes the system
/// accent (ADR 0025). ↑/↓ move through the sessions
/// (`WorkspaceViewModel.selectAdjacentSession`).
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
                newSessionButton
                searchButton
                projectSwitcher
            }
            .padding(.bottom, AppSpacing.sm)
            ScrollView {
                sessionList
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

    // MARK: Sessions

    @ViewBuilder
    private var sessionList: some View {
        if viewModel.selectedProject == nil {
            placeholder(viewModel.projects.projects.isEmpty ? "Open a project folder to start a session."
                                                           : "Choose a project above.")
        } else if viewModel.sessions.sessions.isEmpty {
            placeholder("No sessions yet. Start one with New session.")
        } else {
            // Recomputed with the list, so “Today” rolls over on the next change.
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(viewModel.sessionGroups(now: .now)) { group in
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        SectionHeader(title: group.period.title)
                            .padding(.horizontal, AppSpacing.sm)
                        ForEach(group.sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        SidebarRow(isSelected: session.id == viewModel.selectedSessionID, action: {
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

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.callout)
            .foregroundStyle(AppColors.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.xs)
    }

    // MARK: Project and new session

    private var newSessionButton: some View {
        Button {
            onCommand(.newSession)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "square.and.pencil")
                    .accessibilityHidden(true)
                Text("New session")
                    .lineLimit(1)
                Spacer(minLength: AppSpacing.xs)
                if let shortcut = WorkspaceCommand.newSession.shortcut?.displayString {
                    ShortcutBadge(shortcut: shortcut)
                }
            }
            .font(AppTypography.callout.weight(.medium))
            .foregroundStyle(AppColors.textPrimary)
            .padding(.leading, AppSpacing.md)
            .padding(.trailing, AppSpacing.xs + AppSpacing.xxs)
            .frame(height: AppLayout.buttonHeight)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .appFloating(in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous), interactive: true, elevated: false)
        .disabled(!viewModel.isEnabled(.newSession))
        .help(viewModel.disabledReason(for: .newSession) ?? "Start a new session in this project")
        .padding(.horizontal, AppSpacing.md)
    }

    /// The current project, and every project action, in one menu: the list
    /// below is the project's sessions.
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
                    ProjectBadge(name: project.name, size: 16)
                    Text(project.name)
                        .font(AppTypography.body.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                } else {
                    Image(systemName: "folder")
                        .accessibilityHidden(true)
                    Text("Open a project")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "chevron.up.chevron.down")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: AppLayout.rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help(viewModel.selectedProject?.rootURL.path ?? "Open a project folder")
        .accessibilityLabel("Project")
        .accessibilityValue(viewModel.selectedProject?.name ?? "None")
        .padding(.horizontal, AppSpacing.sm)
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
}

/// One session in the sidebar: its title on one line, and what its agent is
/// doing, as a symbol with a spoken label (never color alone).
private struct SessionRowLabel: View {
    let session: Session
    let activity: SessionActivity?

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(session.title)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: AppSpacing.xs)
            switch activity {
            case .running:
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel("Running")
            case .awaitingApproval:
                Image(systemName: "hand.raised.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.warning)
                    .accessibilityLabel("Waiting for your approval")
            case nil:
                EmptyView()
            }
        }
        .help(details)
        .accessibilityElement(children: .combine)
    }

    /// Shown on hover: the row itself stays on one line, like Claude Code's.
    private var details: String {
        let updated = session.updatedAt.formatted(.relative(presentation: .named, unitsStyle: .wide))
        guard session.toolCallCount > 0 else { return "Updated \(updated)" }
        let calls = session.toolCallCount == 1 ? "1 tool call" : "\(session.toolCallCount) tool calls"
        return "Updated \(updated) · \(calls)"
    }
}
