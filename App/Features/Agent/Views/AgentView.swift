import SwiftUI

/// The conversation for one session: the transcript scrolls under a
/// floating glass composer (and approval banner, when one is pending).
struct AgentView: View {
    @Bindable var viewModel: AgentViewModel
    /// “Provider · model” label shown in the composer, if a model is selected.
    let modelName: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let suggestions = [
        "Explain how this project is structured",
        "Find the TODOs and summarize them",
        "Review the README for missing setup steps"
    ]

    var body: some View {
        Group {
            if viewModel.messages.isEmpty {
                emptyState
            } else {
                transcript
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AppSpacing.sm) {
                if let request = viewModel.pendingApproval {
                    ApprovalBanner(request: request, onDecision: viewModel.resolveApproval)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)
            .frame(maxWidth: AppLayout.readableWidth + 2 * AppSpacing.xl)
            .frame(maxWidth: .infinity)
            .appAnimation(AppAnimation.standard, value: viewModel.pendingApproval)
        }
        .onChange(of: viewModel.announcement) { _, announcement in
            if let announcement { AccessibilityNotification.Announcement(announcement.text).post() }
        }
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                    // Consecutive agent messages (one per tool iteration) share one header.
                    let continuesAgentTurn = index > 0 && viewModel.messages[index - 1].role == .assistant
                    AgentMessageView(message: message, showsHeader: !continuesAgentTurn)
                        .padding(.top, message.role == .user && index > 0 ? AppSpacing.md : 0)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                }
                if viewModel.canRetry {
                    retryButton
                        .padding(.leading, 22 + AppSpacing.md)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: AppLayout.readableWidth, alignment: .leading)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)
            .frame(maxWidth: .infinity)
            .appAnimation(AppAnimation.standard, value: viewModel.messages.count)
        }
        // Keeps the newest content visible while the answer streams in,
        // without scrolling code that would fight the user's own scrolling.
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    }

    private var retryButton: some View {
        Button(action: viewModel.retry) {
            Label("Retry", systemImage: "arrow.clockwise")
                .font(AppTypography.callout)
        }
        .appGlassButton()
        .controlSize(.small)
        .help("Run the last message again")
        .accessibilityHint("Runs your last message again, replacing the failed or stopped answer.")
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            AgentAvatar(size: 44)
            VStack(spacing: AppSpacing.xs) {
                Text("What should we work on?")
                    .font(AppTypography.display)
                    .foregroundStyle(AppColors.textPrimary)
                Text("The agent reads your project freely and asks before changing anything.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            AppGlassContainer {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Self.suggestions, id: \.self) { suggestion in
                        Button {
                            viewModel.draft = suggestion
                        } label: {
                            HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                                Text(suggestion)
                                Image(systemName: "arrow.up.right")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            .font(AppTypography.callout)
                            .padding(.horizontal, AppSpacing.md)
                            .frame(height: 30)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColors.textSecondary)
                        .appGlass(in: Capsule(), interactive: true)
                    }
                }
            }
            .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
