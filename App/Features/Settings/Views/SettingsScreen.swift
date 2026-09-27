import SwiftUI

/// Settings as a screen of the main window, like Linear's: a way back and the
/// sections on the left, the selected section on the inset panel.
///
/// It covers the workspace while open (⌘, or Settings in the sidebar);
/// “Back to app” or Esc returns at once to the workspace as it was left,
/// which stays alive underneath.
struct SettingsScreen: View {
    @Binding var section: SettingsSection
    let agent: AgentSettingsViewModel
    let providers: ProviderSettingsViewModel
    let models: ModelsViewModel
    /// Shared with the workspace, so both sidebars have the same width.
    @Binding var sidebarWidth: Double
    /// False while another layer (the command palette) owns Esc.
    var closesWithEscape = true
    let onClose: () -> Void

    var body: some View {
        SidebarLayout(isSidebarVisible: true, sidebarWidth: $sidebarWidth) {
            sidebar
        } detail: {
            page
        }
        .navigationTitle("Settings")
        // The hidden workspace's message field may still have the keyboard:
        // take it away so typing never goes there.
        .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Room for the traffic lights; dragging it moves the window.
            Color.clear
                .frame(height: AppLayout.windowControlsHeight - AppSpacing.sm)
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
            BackToAppButton(showsShortcut: closesWithEscape, action: onClose)
                .padding(.bottom, AppSpacing.md)
            SectionHeader(title: "Settings")
                .padding(.horizontal, AppSpacing.sm)
            ForEach(SettingsSection.allCases) { item in
                SidebarRow(isSelected: item == section, action: { section = item }, label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: AppLayout.rowIconWidth)
                            .accessibilityHidden(true)
                        Text(item.title)
                    }
                })
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.sm)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppColors.background)
    }

    /// The selected section on the content panel, with its title above.
    private var page: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(section.title)
                    .font(AppTypography.display)
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(section.subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.sm)
            content
        }
        .frame(maxWidth: AppLayout.settingsWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: AppBorders.hairline)
        )
        .padding([.bottom, .trailing], AppSpacing.sm)
        .padding(.leading, AppSpacing.xxs)
        .padding(.top, AppSpacing.sm)
        .background(AppColors.background)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .general: GeneralSettingsView(agent: agent)
        case .systemPrompt: SystemPromptSettingsView(agent: agent)
        case .providers: ProvidersSettingsView(viewModel: providers, models: models)
        }
    }
}

/// Linear's way out of settings: “‹ Back to app” as a sidebar-height row,
/// secondary until hovered, with its Esc key shown on hover.
private struct BackToAppButton: View {
    let showsShortcut: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "chevron.left")
                    .font(AppTypography.caption.weight(.semibold))
                    .frame(width: AppLayout.rowIconWidth)
                Text("Back to app")
                    .font(AppTypography.headline)
                Spacer(minLength: AppSpacing.sm)
            }
        }
        .buttonStyle(BackRowStyle(showsShortcut: showsShortcut))
        .keyboardShortcut(showsShortcut ? .cancelAction : nil)
        .help(showsShortcut ? "Back to the workspace (Esc)" : "Back to the workspace")
        .accessibilityLabel("Back to app")
    }
}

private struct BackRowStyle: ButtonStyle {
    let showsShortcut: Bool

    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration, showsShortcut: showsShortcut)
    }

    private struct Row: View {
        let configuration: Configuration
        let showsShortcut: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isHovered ? AppColors.textPrimary : AppColors.textSecondary)
                .overlay(alignment: .trailing) {
                    if showsShortcut {
                        ShortcutBadge(shortcut: "Esc")
                            .opacity(isHovered ? 1 : 0)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: AppLayout.rowHeight, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(configuration.isPressed ? AppColors.selection : (isHovered ? AppColors.hover : .clear))
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .onHover { isHovered = $0 }
                .appAnimation(AppAnimation.quick, value: isHovered)
        }
    }
}
