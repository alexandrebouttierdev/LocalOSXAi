import SwiftUI

/// Right-hand panel: model, context (usage and length) and Git state for the
/// current session.
struct InspectorView: View {
    let viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                InspectorSection(title: "Model") {
                    ModelPickerView(viewModel: viewModel.models)
                    if viewModel.models.selectedModel?.supportsTools == false {
                        placeholder("This model does not support tools: the agent can only chat.")
                    }
                }
                InspectorSection(title: "Context") {
                    if let usage = viewModel.activeAgent?.contextUsage {
                        ContextMeterView(usage: usage)
                    } else {
                        placeholder("Context usage appears after the first run.")
                    }
                    if let model = viewModel.models.selectedModel {
                        ContextLengthPicker(viewModel: viewModel.models, model: model)
                    }
                    if let sources = viewModel.activeAgent?.instructionSources, !sources.isEmpty {
                        Label("Instructions: \(sources.joined(separator: ", "))", systemImage: "doc.text")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    if let project = viewModel.selectedProject {
                        Toggle("Also read CLAUDE.md", isOn: Binding(
                            get: { project.includesClaudeInstructions },
                            set: { value in Task { await viewModel.projects.setIncludesClaudeInstructions(value, for: project.id) } }
                        ))
                        .toggleStyle(.checkbox)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .help("Give the agent this project's CLAUDE.md after AGENTS.md. Applies to the next run.")
                    }
                }
                InspectorSection(title: "Git") {
                    if let git = viewModel.activePanels?.git {
                        GitSummaryView(viewModel: git)
                            .task(id: git.projectRoot) { await git.refresh() }
                    } else {
                        placeholder("Open a project to see its Git status.")
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Linear's opaque ground, like the sidebar: no desktop tint.
        .background(AppColors.background)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.callout)
            .foregroundStyle(AppColors.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: title)
            content
        }
    }
}
