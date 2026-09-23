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
                }
                InspectorSection(title: "Tools") {
                    if viewModel.toolDefinitions.isEmpty {
                        placeholder("No tools registered. Filesystem tools arrive in Phase 3; terminal and Git tools in Phase 4.")
                    } else {
                        ForEach(viewModel.toolDefinitions, id: \.name) { tool in
                            Text(tool.name)
                                .font(AppTypography.code)
                                .foregroundStyle(AppColors.textPrimary)
                                .help(tool.description)
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
