import SwiftUI

/// A diff like Linear's: an optional file header (icon, name, folder, badge,
/// “+12 −3”), then one row per line with its number, a thin red or green
/// bar on changed lines over a faint tint, and syntax colors.
///
/// Rows always span the full width, so short files never float in the
/// middle; long lines scroll horizontally. Added and removed lines keep a
/// “+”/“−” sign in the gutter, so the change is not conveyed by color alone.
struct DiffView: View {
    enum Layout: String, CaseIterable, Identifiable, Sendable {
        /// One column, removed lines above the added ones.
        case unified
        /// Old on the left, new on the right, like Linear's reviews.
        case split

        var id: String { rawValue }
        var title: String { self == .unified ? "Unified" : "Split" }
    }

    let diff: FileDiff
    /// Shown in the header and used for syntax colors.
    var path: String?
    /// False where the file is already named above (Changes tab).
    var showsHeader = true
    /// A word after the path, such as “New file”.
    var badge: String?
    /// The lines' height limit; `nil` fills the available space (Changes tab).
    var maxHeight: CGFloat?
    var layout = Layout.unified

    static let lineHeight: CGFloat = 20
    @State private var viewportWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader, let path {
                header(path)
                Rectangle().fill(AppColors.hairline).frame(height: AppBorders.hairline)
            }
            if diff.isEmpty {
                Text("No differences.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
            } else {
                lines
            }
        }
    }

    private func header(_ path: String) -> some View {
        let name = (path as NSString).lastPathComponent
        let folder = (path as NSString).deletingLastPathComponent
        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: "doc.text")
                .foregroundStyle(AppColors.Hue.blue)
                .accessibilityHidden(true)
            Text(name)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
            if !folder.isEmpty {
                Text(folder)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            if let badge {
                Text(badge)
                    .font(AppTypography.caption.weight(.medium))
                    .foregroundStyle(AppColors.success)
                    .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
                    .frame(height: AppLayout.rowHeight - AppSpacing.sm)
                    .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: AppBorders.hairline))
            }
            Spacer(minLength: AppSpacing.sm)
            DiffStatView(added: diff.addedLines, removed: diff.removedLines)
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: AppLayout.rowHeight + AppSpacing.sm)
        .help(path)
    }

    private var rows: [Row] {
        // A single hunk starting at the first line (a new or small file) needs no “@@” header.
        let showsHeaders = diff.hunks.count > 1
            || diff.hunks.first?.lines.first.map { ($0.newNumber ?? $0.oldNumber ?? 1) > 1 } == true
        return diff.hunks.enumerated().flatMap { index, hunk in
            let lines = layout == .split
                ? hunk.splitRows.enumerated().map { offset, pair in Row.split(index, offset, pair) }
                : hunk.lines.enumerated().map { offset, line in Row.line(index, offset, line) }
            return (showsHeaders ? [Row.hunk(index, hunk.header)] : []) + lines
        }
    }

    private var lines: some View {
        let rows = rows
        let language = SyntaxHighlighter.Language.forPath(path ?? "")
        let digits = String(diff.hunks.flatMap(\.lines).compactMap { $0.newNumber ?? $0.oldNumber }.max() ?? 1).count
        let content = CGFloat(rows.count) * Self.lineHeight + 2 * AppSpacing.xs
        // Split halves clip long lines, like Linear; unified lines scroll.
        return ScrollView(layout == .split ? .vertical : [.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    switch row {
                    case let .hunk(_, header):
                        HunkHeaderRow(header: header)
                    case let .line(_, _, line):
                        DiffLineRow(line: line, number: line.newNumber ?? line.oldNumber, language: language,
                                    gutterDigits: digits)
                    case let .split(_, _, pair):
                        HStack(spacing: 0) {
                            half(pair.old, number: pair.old?.oldNumber, language: language, digits: digits)
                            Rectangle().fill(AppColors.hairline).frame(width: AppBorders.hairline)
                            half(pair.new, number: pair.new?.newNumber, language: language, digits: digits)
                        }
                    }
                }
            }
            .padding(.vertical, AppSpacing.xs)
            // Rows fill the visible width even when every line is short.
            .frame(minWidth: layout == .split ? nil : viewportWidth, alignment: .topLeading)
            .textSelection(.enabled)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewportWidth = $0 }
        .frame(height: maxHeight.map { min(content, $0) })
    }

    /// Exactly half of the visible width, so both sides line up.
    private var halfWidth: CGFloat { max((viewportWidth - AppBorders.hairline) / 2, 0) }

    /// One side of a split row: the line, clipped to its half, or a blank.
    @ViewBuilder
    private func half(_ line: FileDiff.Line?, number: Int?, language: SyntaxHighlighter.Language, digits: Int) -> some View {
        if let line {
            DiffLineRow(line: line, number: number, language: language, gutterDigits: digits)
                .frame(width: halfWidth, alignment: .leading)
                .clipped()
        } else {
            AppColors.hover
                .frame(width: halfWidth, height: Self.lineHeight)
                .accessibilityHidden(true)
        }
    }

    private enum Row: Identifiable {
        case hunk(Int, String)
        case line(Int, Int, FileDiff.Line)
        case split(Int, Int, FileDiff.SplitRow)

        var id: String {
            switch self {
            case let .hunk(hunk, _): "h\(hunk)"
            case let .line(hunk, index, _): "l\(hunk).\(index)"
            case let .split(hunk, index, _): "s\(hunk).\(index)"
            }
        }
    }
}

/// “@@ -10,7 +10,9 @@”, quiet, between hunks.
private struct HunkHeaderRow: View {
    let header: String

    var body: some View {
        Text(header)
            .font(AppTypography.code)
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, AppSpacing.md)
            .frame(maxWidth: .infinity, minHeight: DiffView.lineHeight, alignment: .leading)
            .background(AppColors.hover)
    }
}

private struct DiffLineRow: View {
    let line: FileDiff.Line
    /// The old number on the old side of a split diff, else the new one.
    let number: Int?
    let language: SyntaxHighlighter.Language
    let gutterDigits: Int

    private static let barWidth: CGFloat = 2
    private static let tintOpacity = 0.08

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(color ?? .clear)
                .frame(width: Self.barWidth)
            Text(number.map(String.init) ?? "")
                .foregroundStyle(color ?? AppColors.textTertiary)
                .frame(width: CGFloat(max(gutterDigits, 2)) * AppSpacing.sm, alignment: .trailing)
                .padding(.leading, AppSpacing.sm)
            Text(sign)
                .foregroundStyle(color ?? AppColors.textTertiary)
                .frame(width: AppSpacing.lg)
            Text(highlighted)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, AppSpacing.md)
        }
        .font(AppTypography.code)
        .frame(maxWidth: .infinity, minHeight: DiffView.lineHeight, alignment: .leading)
        .background((color ?? .clear).opacity(Self.tintOpacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilityKind) line \(line.newNumber ?? line.oldNumber ?? 0): \(line.text)")
    }

    private var color: Color? {
        switch line.kind {
        case .added: AppColors.success
        case .removed: AppColors.danger
        case .context: nil
        }
    }

    private var sign: String {
        switch line.kind {
        case .added: "+"
        case .removed: "−"
        case .context: ""
        }
    }

    private var accessibilityKind: String {
        switch line.kind {
        case .added: "Added"
        case .removed: "Removed"
        case .context: "Unchanged"
        }
    }

    /// Removed lines are dimmed, like Linear's old side.
    private var highlighted: AttributedString {
        var result = AttributedString()
        for token in SyntaxHighlighter.tokens(in: line.text, language: language) {
            var part = AttributedString(token.text)
            part.foregroundColor = Self.color(for: token.kind)
            result += part
        }
        if line.kind == .removed { result.foregroundColor = AppColors.textSecondary }
        return result
    }

    private static func color(for kind: SyntaxHighlighter.Kind) -> Color {
        switch kind {
        case .plain: AppColors.textPrimary
        case .keyword: AppColors.Hue.orange
        case .string: AppColors.Hue.green
        case .number: AppColors.Hue.yellow
        case .comment: AppColors.textTertiary
        case .type, .tag: AppColors.Hue.blue
        case .attribute: AppColors.Hue.purple
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
