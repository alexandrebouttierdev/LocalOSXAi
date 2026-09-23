import SwiftUI

/// The conversation for one session: transcript above, composer below.
struct AgentView: View {
    @Bindable var viewModel: AgentViewModel
    /// “Provider · model” label shown in the composer, if a model is selected.
    let modelName: String?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.messages.isEmpty {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "Start a conversation",
                    message: "Ask the agent to explain, change or test code in this project."
                )
            } else {
                transcript
            }
            ComposerView(
                draft: $viewModel.draft,
                isRunning: viewModel.isRunning,
                canSend: viewModel.canSend,
                modelName: modelName,
                onSend: viewModel.send,
                onStop: viewModel.cancel
            )
        }
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                ForEach(viewModel.messages) { message in
                    AgentMessageView(message: message)
                }
            }
            .frame(maxWidth: AppLayout.readableWidth, alignment: .leading)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        // Keeps the newest content visible while the answer streams in,
        // without scrolling code that would fight the user's own scrolling.
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    }
}
