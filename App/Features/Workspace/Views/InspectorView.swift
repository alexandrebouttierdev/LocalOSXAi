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
                    if let agent = viewModel.activeAgent {
                        compactButton(agent)
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

    /// Summarizes the session now, like /compact: the messages stay in the
    /// transcript, the model sees only the summary from the next run on.
    private func compactButton(_ agent: AgentViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button(action: agent.compact) {
                HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                    if agent.isCompacting {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                    }
                    Text(agent.isCompacting ? "Compacting…" : "Compact session")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
            .disabled(!agent.canCompact)
            .help(agent.isCompacting
                  ? "The model is summarizing the session. ⌘. stops it."
                  : "Summarize the whole conversation now, so the next message starts with a nearly empty context. "
                    + "The messages stay visible.")
            .accessibilityLabel(agent.isCompacting ? "Compacting session" : "Compact session")
            if let error = agent.compactionError {
                Label([error.message, error.recoverySuggestion].compactMap { $0 }.joined(separator: " "),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, AppSpacing.sm)
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
