import SwiftUI

/// Settings as a screen of the main window, like Linear's: a way back and the
/// sections on the left, the selected section on the inset panel.
///
/// It replaces the workspace while open (⌘, or Settings in the sidebar);
/// “Back to app” or Esc returns to the workspace as it was left.
struct SettingsScreen: View {
    @Binding var section: SettingsSection
    let agent: AgentSettingsViewModel
    let providers: ProviderSettingsViewModel
    let models: ModelsViewModel
    /// False while another layer (the command palette) owns Esc.
    var closesWithEscape = true
    let onClose: () -> Void

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: AppLayout.sidebarMinWidth, ideal: AppLayout.sidebarIdealWidth, max: AppLayout.sidebarMaxWidth
                )
        } detail: {
            page
                .navigationTitle("Settings")
                .navigationSubtitle(section.title)
                .toolbarBackground(AppColors.background, for: .windowToolbar)
        }
    }

    private var sidebar: some View {
        List(selection: selection) {
            Section {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            } header: {
                SectionHeader(title: "Settings")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .safeAreaInset(edge: .top, spacing: 0) { backButton }
    }

    private var backButton: some View {
        Button(action: onClose) {
            Label("Back to app", systemImage: "chevron.left")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.subtle)
        .keyboardShortcut(closesWithEscape ? .cancelAction : nil)
        .help("Back to the workspace (Esc)")
        .padding(.horizontal, AppSpacing.sm)
        .padding(.top, AppSpacing.sm)
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
        .padding(.top, AppSpacing.xs)
        .background(AppColors.background)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .general: GeneralSettingsView(agent: agent)
        case .providers: ProvidersSettingsView(viewModel: providers, models: models)
        }
    }

    /// `List` selection is optional; a section is always selected.
    private var selection: Binding<SettingsSection?> {
        Binding(get: { section }, set: { if let value = $0 { section = value } })
    }
}
