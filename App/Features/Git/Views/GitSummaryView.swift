import SwiftUI

/// Git state as inspector properties, like Linear's: branch (with how far it
/// is ahead or behind), changed files, last commit.
struct GitSummaryView: View {
    let viewModel: GitViewModel
    static let maxFiles = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch viewModel.state {
            case .loading:
                PropertyRow(label: "Branch") { ProgressView().controlSize(.mini) }
            case .notARepository:
                PropertyRow(label: "Branch") {
                    PropertyValue("Not a Git repository", systemImage: "arrow.triangle.branch", isPlaceholder: true,
                                  isInteractive: false)
                }
            case .failed(let message):
                PropertyRow(label: "Branch") { placeholder(message) }
            case let .loaded(status, lastCommit):
                PropertyRow(label: "Branch") {
                    HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                        PropertyValue(status.branch ?? "Detached HEAD", systemImage: "arrow.triangle.branch", isInteractive: false,
                                      tint: AppColors.Hue.purple)
                            .fixedSize()
                        if status.ahead > 0 || status.behind > 0 {
                            Text([status.ahead > 0 ? "↑\(status.ahead)" : nil, status.behind > 0 ? "↓\(status.behind)" : nil]
                                    .compactMap { $0 }.joined(separator: " "))
                                .font(AppTypography.caption.monospacedDigit())
                                .foregroundStyle(AppColors.textTertiary)
                                .accessibilityLabel("\(status.ahead) ahead, \(status.behind) behind")
                        }
                    }
                }
                PropertyRow(label: "Changes") {
                    PropertyValue(status.isClean ? "Clean" : (status.files.count == 1 ? "1 file" : "\(status.files.count) files"),
                                  systemImage: status.isClean ? "checkmark.circle" : "plusminus", isPlaceholder: status.isClean,
                                  isInteractive: false, tint: status.isClean ? AppColors.Hue.green : AppColors.Hue.orange)
                }
                if !status.isClean {
                    files(status.files)
                }
                if let lastCommit {
                    PropertyRow(label: "Commit") {
                        HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                            Text(lastCommit.shortHash)
                                .font(AppTypography.code)
                                .foregroundStyle(AppColors.Hue.yellow)
                            Text(lastCommit.subject)
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
                        .help(lastCommit.subject)
                    }
                }
            }
        }
    }

    /// The first changed files, under the Changes row and aligned with values.
    private func files(_ files: [GitFileChange]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            ForEach(files.prefix(Self.maxFiles), id: \.self) { file in
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
            if files.count > Self.maxFiles {
                Text("+ \(files.count - Self.maxFiles) more")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.leading, AppLayout.propertyLabelWidth + AppSpacing.sm + AppSpacing.xs + AppSpacing.xxs)
        .padding(.bottom, AppSpacing.xs)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.callout)
            .foregroundStyle(AppColors.textTertiary)
            .lineLimit(2)
            .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
    }

    private func color(for kind: GitFileChange.Kind) -> Color {
        switch kind {
        case .added, .untracked: AppColors.success
        case .deleted, .conflicted: AppColors.danger
        default: AppColors.warning
        }
    }
}
