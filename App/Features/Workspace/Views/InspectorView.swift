import SwiftUI

/// Right-hand panel: model, context budget, tools and Git state for the
/// current session.
struct InspectorView: View {
    let viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                InspectorSection(title: "Model") {
                    ModelPickerView(viewModel: viewModel.models)
                }
                InspectorSection(title: "Context") {
                    if let usage = viewModel.activeAgent?.contextUsage {
                        ContextMeterView(usage: usage)
                    } else {
                        placeholder("Context usage appears after the first run.")
                    }
                    if let sources = viewModel.activeAgent?.instructionSources, !sources.isEmpty {
                        Label("Instructions: \(sources.joined(separator: ", "))", systemImage: "doc.text")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                InspectorSection(title: "Tools") {
                    if viewModel.toolDefinitions.isEmpty {
                        placeholder("No tools available.")
                    } else {
                        ForEach(viewModel.toolDefinitions, id: \.name) { tool in
                            Text(tool.name)
                                .font(AppTypography.code)
                                .foregroundStyle(AppColors.textPrimary)
                                .help(tool.description)
                        }
                        if viewModel.models.selectedModel?.supportsTools == false {
                            placeholder("The selected model does not support tools: the agent can only chat.")
                        } else {
                            placeholder("File changes and commands that change things ask for your approval.")
                        }
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
        // No background: the inspector uses the native (glass) material.
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
