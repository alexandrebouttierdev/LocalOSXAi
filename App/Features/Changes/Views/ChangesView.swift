import SwiftUI

/// Review of the agent's file changes: list on the left, diff on the right,
/// accept or revert per file or all at once.
struct ChangesView: View {
    @Bindable var viewModel: ChangesViewModel
    @State private var isConfirmingRevertAll = false
    /// Remembered between launches, like Linear's diff mode.
    @AppStorage("changes.diffLayout") private var layout = DiffView.Layout.split

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
            SectionHeader(title: "Pending review \(viewModel.changes.count)") {
                DiffStatView(added: viewModel.totals.added, removed: viewModel.totals.removed)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: AppLayout.panelHeaderHeight)
            ScrollView {
                LazyVStack(spacing: AppSpacing.xxs) {
                    ForEach(viewModel.changes) { change in
                        ChangeRow(change: change, isSelected: change.file == viewModel.selectedChange?.file) {
                            viewModel.selectedFile = change.file
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { viewModel.selectAdjacent(-1); return .handled }
            .onKeyPress(.downArrow) { viewModel.selectAdjacent(1); return .handled }
            Rectangle().fill(AppColors.hairline).frame(height: AppBorders.hairline)
            HStack(spacing: AppSpacing.sm) {
                Button("Reject All", role: .destructive) { isConfirmingRevertAll = true }
                    .appButton()
                Spacer()
                Button("Accept All") { Task { await viewModel.acceptAll() } }
                    .appButton(prominent: true)
            }
            .padding(AppSpacing.sm)
        }
        .background(AppColors.surface)
    }

    @ViewBuilder
    private var detail: some View {
        if let change = viewModel.selectedChange {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.sm) {
                    ChangeStatusIcon(status: change.status)
                    breadcrumb(change.path)
                    DiffStatView(added: change.diff.addedLines, removed: change.diff.removedLines)
                    Spacer(minLength: AppSpacing.sm)
                    PillPicker(options: DiffView.Layout.allCases, selection: $layout, title: \.title)
                    Button("Revert", systemImage: "arrow.uturn.backward") { Task { await viewModel.revert(change) } }
                        .appButton()
                        .help("Restore the file as it was before the agent changed it")
                    Button("Accept", systemImage: "checkmark") { Task { await viewModel.accept(change) } }
                        .appButton(prominent: true)
                        .help("Keep this change and remove it from the list")
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: AppLayout.panelHeaderHeight)
                Rectangle().fill(AppColors.hairline).frame(height: AppBorders.hairline)
                DiffView(diff: change.diff, path: change.path, badge: change.status == .created ? "New file" : nil,
                         layout: layout)
                    .background(AppColors.codeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                            .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
                    )
                    .padding(AppSpacing.md)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .background(AppColors.surface)
        }
    }

    /// “Sources › Views › App.swift”, the file name in full strength.
    private func breadcrumb(_ path: String) -> some View {
        let parts = path.split(separator: "/").map(String.init)
        return HStack(spacing: AppSpacing.xs) {
            ForEach(Array(parts.dropLast().suffix(2).enumerated()), id: \.offset) { _, folder in
                Text(folder).foregroundStyle(AppColors.textTertiary)
                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Text(parts.last ?? path)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
        }
        .font(AppTypography.callout)
        .lineLimit(1)
        .help(path)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(path)
    }
}

/// A changed file in the review list, like a Linear review row: its name and
/// “+12 −3”, then its status and folder.
private struct ChangeRow: View {
    let change: FileChange
    let isSelected: Bool
    let select: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.sm) {
                    Text((change.path as NSString).lastPathComponent)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: AppSpacing.xs)
                    DiffStatView(added: change.diff.addedLines, removed: change.diff.removedLines)
                }
                HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                    ChangeStatusIcon(status: change.status)
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(isSelected ? AppColors.selection : (isHovered ? AppColors.hover : .clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
        .accessibilityLabel("\(change.path), \(change.status.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var detail: String {
        let folder = (change.path as NSString).deletingLastPathComponent
        return folder.isEmpty ? change.status.title : "\(change.status.title) · \(folder)"
    }
}

/// Created, modified or deleted, as a small colored mark (the word is next to it).
private struct ChangeStatusIcon: View {
    let status: FileChange.Status

    var body: some View {
        Image(systemName: symbol)
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch status {
        case .created: "plus.circle.fill"
        case .modified: "pencil.circle.fill"
        case .deleted: "minus.circle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .created: AppColors.success
        case .modified: AppColors.warning
        case .deleted: AppColors.danger
        }
    }
}
