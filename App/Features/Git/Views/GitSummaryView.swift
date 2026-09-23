import SwiftUI

/// Compact Git state for the inspector: branch, sync state, changed files,
/// last commit.
struct GitSummaryView: View {
    let viewModel: GitViewModel
    static let maxFiles = 8

    var body: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().controlSize(.small)
        case .notARepository:
            note("Not a Git repository.")
        case .failed(let message):
            note(message)
        case let .loaded(status, lastCommit):
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                    Image(systemName: "arrow.triangle.branch").foregroundStyle(AppColors.textSecondary)
                    Text(status.branch ?? "Detached HEAD").font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 0)
                    if status.ahead > 0 { StatusBadge(title: "↑\(status.ahead)", systemImage: "arrow.up", tone: .accent) }
                    if status.behind > 0 { StatusBadge(title: "↓\(status.behind)", systemImage: "arrow.down", tone: .warning) }
                }
                if status.isClean {
                    Label("Working tree clean", systemImage: "checkmark.circle")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    ForEach(status.files.prefix(Self.maxFiles), id: \.self) { file in
                        HStack(spacing: AppSpacing.sm) {
                            Text(file.code)
                                .font(AppTypography.code.weight(.semibold))
                                .foregroundStyle(color(for: file.kind))
                                .frame(width: 12)
                            Text(file.path)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(file.kind.rawValue) \(file.path)\(file.isStaged ? ", staged" : "")")
                    }
                    if status.files.count > Self.maxFiles {
                        note("+ \(status.files.count - Self.maxFiles) more")
                    }
                }
                if let lastCommit {
                    Text("\(lastCommit.shortHash) · \(lastCommit.subject)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(AppTypography.callout).foregroundStyle(AppColors.textTertiary)
    }

    private func color(for kind: GitFileChange.Kind) -> Color {
        switch kind {
        case .added, .untracked: AppColors.success
        case .deleted, .conflicted: AppColors.danger
        default: AppColors.warning
        }
    }
}
