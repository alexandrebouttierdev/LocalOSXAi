import SwiftUI

/// A unified diff with line numbers, colored gutters and hunk headers.
/// Added and removed lines carry “+”/“−” signs, so the change is not
/// conveyed by color alone.
struct DiffView: View {
    let diff: FileDiff

    var body: some View {
        if diff.isEmpty {
            Text("No differences.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textTertiary)
                .padding(AppSpacing.md)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diff.hunks.enumerated()), id: \.offset) { _, hunk in
                    Text(hunk.header)
                        .font(AppTypography.code)
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xxs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.accentSubtle)
                    ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                        DiffLineView(line: line)
                    }
                }
            }
            .textSelection(.enabled)
        }
    }
}

private struct DiffLineView: View {
    let line: FileDiff.Line

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            number(line.oldNumber)
            number(line.newNumber)
            Text(sign)
                .foregroundStyle(signColor)
                .frame(width: 16)
            Text(line.text.isEmpty ? " " : line.text)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
        }
        .font(AppTypography.code)
        .padding(.vertical, 1)
        .background(background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessibilityKind) \(line.text)")
    }

    private func number(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "")
            .foregroundStyle(AppColors.textTertiary)
            .frame(width: 40, alignment: .trailing)
            .padding(.trailing, AppSpacing.xs)
    }

    private var sign: String {
        switch line.kind {
        case .added: "+"
        case .removed: "−"
        case .context: " "
        }
    }

    private var signColor: Color {
        switch line.kind {
        case .added: AppColors.success
        case .removed: AppColors.danger
        case .context: AppColors.textTertiary
        }
    }

    private var background: Color {
        switch line.kind {
        case .added: AppColors.success.opacity(0.12)
        case .removed: AppColors.danger.opacity(0.12)
        case .context: .clear
        }
    }

    private var accessibilityKind: String {
        switch line.kind {
        case .added: "Added"
        case .removed: "Removed"
        case .context: "Unchanged"
        }
    }
}

/// “+12 −3”, with the counts spelled out for VoiceOver.
struct DiffStatView: View {
    let added: Int
    let removed: Int

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text("+\(added)").foregroundStyle(AppColors.success)
            Text("−\(removed)").foregroundStyle(AppColors.danger)
        }
        .font(AppTypography.caption.monospacedDigit().weight(.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(added) lines added, \(removed) removed")
    }
}
