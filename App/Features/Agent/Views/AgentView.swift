import SwiftUI

/// The conversation for one session: the transcript scrolls under a
/// floating glass composer (and approval banner, when one is pending).
struct AgentView: View {
    let viewModel: AgentViewModel
    /// “Provider · model” label shown in the composer, if a model is selected.
    let modelName: String?

    @State private var isDropTargeted = false

    static let suggestions = [
        "Explain how this project is structured",
        "Find the TODOs and summarize them",
        "Review the README for missing setup steps"
    ]

    var body: some View {
        // Reads only what changes the layout. The transcript and the composer
        // are separate views, so typing never re-renders the conversation.
        Group {
            if viewModel.messages.isEmpty {
                emptyState
            } else {
                TranscriptView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AppSpacing.sm) {
                if let request = viewModel.pendingApproval {
                    ApprovalBanner(request: request, onDecision: viewModel.resolveApproval)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                AgentComposer(viewModel: viewModel, modelName: modelName, isDropTargeted: isDropTargeted)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)
            .frame(maxWidth: AppLayout.readableWidth + 2 * AppSpacing.xl)
            .frame(maxWidth: .infinity)
            .appAnimation(AppAnimation.standard, value: viewModel.pendingApproval)
        }
        // Files dropped anywhere on the conversation are attached to the draft.
        .dropDestination(for: URL.self) { files, _ in
            guard viewModel.canAttach else { return false }
            Task { await viewModel.attach(files) }
            return true
        } isTargeted: { isDropTargeted = viewModel.canAttach && $0 }
        .onChange(of: viewModel.announcement) { _, announcement in
            if let announcement { AccessibilityNotification.Announcement(announcement.text).post() }
        }
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
            Group {
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
                            .frame(height: AppLayout.buttonHeight)
                            .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColors.textSecondary)
                        .appFloating(in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous),
                                     interactive: true, elevated: false)
                    }
                }
            }
            .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The composer bound to the draft: the only view that re-renders while the
/// user types.
private struct AgentComposer: View {
    @Bindable var viewModel: AgentViewModel
    let modelName: String?
    let isDropTargeted: Bool

    var body: some View {
        ComposerView(
            draft: $viewModel.draft,
            isRunning: viewModel.isRunning,
            canSend: viewModel.canSend,
            modelName: modelName,
            attachments: viewModel.draftAttachments,
            attachmentError: viewModel.attachmentError,
            canAttach: viewModel.canAttach,
            isDropTargeted: isDropTargeted,
            onAttach: { files in Task { await viewModel.attach(files) } },
            onRemoveAttachment: viewModel.removeAttachment,
            onSend: viewModel.send,
            onStop: viewModel.cancel
        )
    }
}

/// The messages, kept at the bottom while the user is there.
///
/// When the content or the room around it changes (an answer streaming in,
/// the approval card appearing or leaving, the composer growing), the view
/// scrolls back to the end if it was there just before. Approving a change
/// therefore never leaves an empty gap, and a user who scrolled up to read
/// is left where they are.
private struct TranscriptView: View {
    let viewModel: AgentViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = ScrollPosition(edge: .bottom)

    /// How close to the end still counts as “at the bottom”.
    private static let bottomTolerance: CGFloat = 48

    /// Where the scroll stands relative to its end.
    private struct Metrics: Equatable {
        /// Largest possible offset: changes with the content and the room around it.
        var maxOffset: CGFloat
        /// Distance left to the end; negative past it (an empty gap).
        var distanceToEnd: CGFloat
    }

    var body: some View {
        ScrollView {
            transcriptContent
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom)
        .onScrollGeometryChange(for: Metrics.self) { geometry in
            let maxOffset = geometry.contentSize.height + geometry.contentInsets.bottom - geometry.containerSize.height
            return Metrics(maxOffset: maxOffset, distanceToEnd: maxOffset - geometry.contentOffset.y)
        } action: { old, new in
            // Only a resize moves the view: the user's own scrolling, elastic
            // bounce included, never does.
            let resized = abs(new.maxOffset - old.maxOffset) > 0.5
            if resized, old.distanceToEnd <= Self.bottomTolerance || new.distanceToEnd < 0 {
                position.scrollTo(edge: .bottom)
            }
        }
        // Sending a message always shows it, even after the user scrolled
        // up to read: it is the user's own action, so it cannot fight them.
        .onChange(of: viewModel.latestPromptID) {
            position.scrollTo(edge: .bottom)
        }
    }

    private var transcriptContent: some View {
        LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
            let turnStats = viewModel.turnStats
            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                // Consecutive agent messages (one per tool iteration) share one header.
                let continuesAgentTurn = index > 0 && viewModel.messages[index - 1].role == .assistant
                AgentMessageView(message: message, showsHeader: !continuesAgentTurn, turnStats: turnStats[index])
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

    private var retryButton: some View {
        Button(action: viewModel.retry) {
            Label("Retry", systemImage: "arrow.clockwise")
                .font(AppTypography.callout)
        }
        .appButton()
        .controlSize(.small)
        .help("Run the last message again")
        .accessibilityHint("Runs your last message again, replacing the failed or stopped answer.")
    }
}
