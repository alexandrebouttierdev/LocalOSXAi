import SwiftUI

/// Review of the agent's file changes: list on the left, diff on the right,
/// accept or revert per file or all at once.
struct ChangesView: View {
    @Bindable var viewModel: ChangesViewModel
    @State private var isConfirmingRevertAll = false

    var body: some View {
        Group {
            if viewModel.changes.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.seal",
                    title: "No pending changes",
                    message: "Files the agent creates or edits appear here, so you can review, keep or revert them."
                )
            } else {
                HSplitView {
                    fileList
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 360)
                    detail
                        .frame(minWidth: 320)
                }
            }
        }
        .task { await viewModel.refresh() }
        .confirmationDialog("Revert all changes?", isPresented: $isConfirmingRevertAll) {
            Button("Revert All", role: .destructive) { Task { await viewModel.revertAll() } }
        } message: {
            Text("Every file the agent changed in this project is restored, and created files are deleted.")
        }
        .alert(viewModel.error?.title ?? "",
               isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } }),
               presenting: viewModel.error) { _ in
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: { error in
            Text(error.message)
        }
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(viewModel.changes.count) file\(viewModel.changes.count == 1 ? "" : "s")")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                DiffStatView(added: viewModel.totals.added, removed: viewModel.totals.removed)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 36)
            List(viewModel.changes, selection: $viewModel.selectedFile) { change in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: icon(for: change.status))
                        .foregroundStyle(color(for: change.status))
                        .accessibilityLabel(change.status.rawValue)
                    Text(change.path)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    DiffStatView(added: change.diff.addedLines, removed: change.diff.removedLines)
                }
                .tag(change.file)
            }
            .listStyle(.sidebar)
            Divider().overlay(AppColors.border)
            HStack(spacing: AppSpacing.sm) {
                Button("Reject All", role: .destructive) { isConfirmingRevertAll = true }
                    .appGlassButton()
                Spacer()
                Button("Accept All") { Task { await viewModel.acceptAll() } }
                    .appGlassButton(prominent: true)
            }
            .padding(AppSpacing.sm)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let change = viewModel.selectedChange {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.sm) {
                    Text(change.path)
                        .font(AppTypography.headline)
                        .lineLimit(1)
                        .truncationMode(.head)
                    StatusBadge(title: change.status.rawValue.capitalized, systemImage: icon(for: change.status),
                                tone: change.status == .deleted ? .danger : change.status == .created ? .success : .warning)
                    Spacer()
                    Button("Revert", systemImage: "arrow.uturn.backward") { Task { await viewModel.revert(change) } }
                        .appGlassButton()
                        .help("Restore the file as it was before the agent changed it")
                    Button("Accept", systemImage: "checkmark") { Task { await viewModel.accept(change) } }
                        .appGlassButton(prominent: true)
                        .help("Keep this change and remove it from the list")
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 44)
                Divider().overlay(AppColors.border)
                ScrollView([.vertical, .horizontal]) {
                    DiffView(diff: change.diff)
                        .padding(.vertical, AppSpacing.sm)
                }
                .background(AppColors.codeBackground)
            }
        }
    }

    private func icon(for status: FileChange.Status) -> String {
        switch status {
        case .created: "plus.circle.fill"
        case .modified: "pencil.circle.fill"
        case .deleted: "minus.circle.fill"
        }
    }

    private func color(for status: FileChange.Status) -> Color {
        switch status {
        case .created: AppColors.success
        case .modified: AppColors.warning
        case .deleted: AppColors.danger
        }
    }
}
