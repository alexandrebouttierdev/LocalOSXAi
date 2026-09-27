import SwiftUI

/// The properties column of the content panel, like Linear's issue
/// properties: label/value rows for the model, the context and Git, every
/// changeable value a menu or switch on its row.
struct InspectorView: View {
    let viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                section("Model") {
                    ModelPropertiesView(viewModel: viewModel.models)
                    if viewModel.models.selectedModel?.supportsTools == false {
                        note("This model does not support tools: the agent can only chat.")
                    }
                }
                section("Context") {
                    PropertyRow(label: "Usage") {
                        if let usage = viewModel.activeAgent?.contextUsage {
                            ContextMeterView(usage: usage)
                                .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
                        } else {
                            value("After the first message")
                        }
                    }
                    PropertyRow(label: "Instructions") {
                        let sources = viewModel.activeAgent?.instructionSources ?? []
                        PropertyValue(sources.isEmpty ? "None" : sources.joined(separator: ", "), systemImage: "doc.text",
                                      isPlaceholder: sources.isEmpty, isInteractive: false)
                            .help("Instruction files the last run gave the model.")
                    }
                    if let project = viewModel.selectedProject {
                        PropertyRow(label: "CLAUDE.md") {
                            Toggle("Also read CLAUDE.md", isOn: Binding(
                                get: { project.includesClaudeInstructions },
                                set: { value in Task { await viewModel.projects.setIncludesClaudeInstructions(value, for: project.id) } }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                            .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
                            .help("Give the agent this project's CLAUDE.md after AGENTS.md. Applies to the next run.")
                        }
                    }
                }
                section("Git") {
                    if let git = viewModel.activePanels?.git {
                        GitSummaryView(viewModel: git)
                            .task(id: git.projectRoot) { await git.refresh() }
                    } else {
                        note("Open a project to see its Git status.")
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeader(title: title)
            content()
        }
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.callout)
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, AppSpacing.xxs)
    }
}
