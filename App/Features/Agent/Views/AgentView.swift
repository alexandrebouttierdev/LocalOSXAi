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
            if let request = viewModel.pendingApproval {
                ApprovalBanner(request: request, onDecision: viewModel.resolveApproval)
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
                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                    // Consecutive agent messages (one per tool iteration) share one header.
                    let continuesAgentTurn = index > 0 && viewModel.messages[index - 1].role == .assistant
                    AgentMessageView(message: message, showsHeader: !continuesAgentTurn)
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
