import SwiftUI

/// The update window: the check in progress, then its result. For a newer
/// version it shows the release notes and opens the release page to
/// download it; the app never downloads or replaces itself.
struct UpdateView: View {
    let viewModel: UpdatesViewModel
    @Environment(\.openURL) private var openURL

    private static let width: CGFloat = 460
    private static let iconSize: CGFloat = 44
    private static let notesMaxHeight: CGFloat = 240
    private static let iconTintOpacity = 0.14

    var body: some View {
        content
            .padding(AppSpacing.xl)
            .frame(width: Self.width)
            .background(AppColors.surface)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle, .checking:
            checking
        case .upToDate:
            result(systemImage: "checkmark.seal.fill", tint: AppColors.success, title: "LocalOSXAi is up to date",
                   message: "Version \(currentVersion) is the latest release.") {
                Button("OK", action: viewModel.close)
                    .appButton(prominent: true)
                    .keyboardShortcut(.defaultAction)
            }
        case .available(let release):
            available(release)
        case .failed(let error):
            result(systemImage: "exclamationmark.triangle.fill", tint: AppColors.warning, title: error.title,
                   message: [error.message, error.recoverySuggestion].compactMap(\.self).joined(separator: " ")) {
                Button("Close", action: viewModel.close)
                    .appButton()
                    .keyboardShortcut(.cancelAction)
                Button("Try Again") { Task { await viewModel.checkNow() } }
                    .appButton(prominent: true)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var currentVersion: String { viewModel.currentVersion?.description ?? "—" }

    private var checking: some View {
        HStack(spacing: AppSpacing.md) {
            ProgressView()
                .controlSize(.small)
            Text("Checking for updates…")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
            Spacer(minLength: 0)
            Button("Cancel", action: viewModel.close)
                .appButton()
                .keyboardShortcut(.cancelAction)
        }
    }

    private func available(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                icon("arrow.down", tint: AppColors.accent, filled: true)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("A new version is available")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    versionChange(to: release)
                }
            }
            if !release.notes.isEmpty {
                notes(release.notes)
            }
            Text("Download the new version, then replace LocalOSXAi in your Applications folder. "
                 + "Your sessions and settings are kept.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: AppSpacing.sm) {
                Spacer(minLength: 0)
                Button("Later", action: viewModel.later)
                    .appButton()
                    .keyboardShortcut(.cancelAction)
                    .help("Hide this update until the next launch")
                Button {
                    openURL(release.pageURL)
                    viewModel.close()
                } label: {
                    Label("Download \(release.tag)", systemImage: "arrow.down.circle")
                }
                .appButton(prominent: true)
                .keyboardShortcut(.defaultAction)
                .help(release.pageURL.absoluteString)
                .accessibilityHint("Opens the release page in your browser")
            }
        }
    }

    /// “v0.0.0.1 → v0.0.0.2 · Sep 27, 2026”, the new version in the accent.
    private func versionChange(to release: AppRelease) -> some View {
        HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
            Text("v\(currentVersion)")
                .foregroundStyle(AppColors.textTertiary)
            Image(systemName: "arrow.right")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .accessibilityHidden(true)
            Text("v\(release.version.description)")
                .fontWeight(.medium)
                .foregroundStyle(AppColors.accentText)
                .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
                .padding(.vertical, AppSpacing.xxs)
                .background(Capsule().fill(AppColors.accentSubtle))
            if let date = release.publishedAt {
                Text("· \(date.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .font(AppTypography.callout.monospacedDigit())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Version \(release.version.description) is available. You have version \(currentVersion).")
    }

    private func notes(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeader(title: "What's new")
            ScrollView {
                MarkdownText(text)
                    .padding(AppSpacing.md)
            }
            .frame(maxHeight: Self.notesMaxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .strokeBorder(AppColors.hairline, lineWidth: AppBorders.hairline)
            )
        }
    }

    private func result<Actions: View>(systemImage: String, tint: Color, title: String, message: String,
                                       @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                icon(systemImage, tint: tint, filled: false)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: AppSpacing.sm) {
                Spacer(minLength: 0)
                actions()
            }
        }
    }

    /// A tinted rounded square with a symbol, like Linear's dialog icons.
    private func icon(_ systemImage: String, tint: Color, filled: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: Self.iconSize * 0.45, weight: .semibold))
            .foregroundStyle(filled ? Color.white : tint)
            .frame(width: Self.iconSize, height: Self.iconSize)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                    .fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(Self.iconTintOpacity)))
            )
            .accessibilityHidden(true)
    }
}
