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
                            placeholder("File changes ask for your approval. Terminal and Git tools arrive in Phase 4.")
                        }
                    }
                }
                InspectorSection(title: "Git") {
                    placeholder("Branch and working tree status arrive in Phase 4.")
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
