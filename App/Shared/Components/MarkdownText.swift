import AppKit
import SwiftUI

/// Renders model output: paragraphs with inline Markdown, headings, lists and
/// fenced code blocks with a copy button.
struct MarkdownText: View {
    let blocks: [MarkdownBlock]

    init(_ text: String) {
        blocks = MarkdownParser.blocks(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xxs) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(Self.inline(text))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .lineSpacing(3)
        case let .heading(level, text):
            Text(Self.inline(text))
                .font(level <= 2 ? AppTypography.title : AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, AppSpacing.xs)
                .accessibilityAddTraits(.isHeader)
        case let .listItem(marker, text):
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(marker)
                    .font(AppTypography.body.monospacedDigit())
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(minWidth: 14, alignment: .trailing)
                Text(Self.inline(text))
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(3)
            }
        case let .code(language, code):
            CodeBlockView(language: language, code: code)
        case .rule:
            Divider().overlay(AppColors.border)
        }
    }

    /// Inline Markdown (bold, italics, `code`, links). Falls back to plain
    /// text if the fragment is not valid Markdown.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// A fenced code block: language label, copy button, monospaced text.
struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "code")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                Button {
                    // Copying is a presentational action with no business meaning (docs/architecture/dependency-rules.md).
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.subtle)
                .font(AppTypography.caption)
                .accessibilityLabel(copied ? "Copied" : "Copy code")
            }
            .padding(.leading, AppSpacing.md)
            .padding(.trailing, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            Divider().overlay(AppColors.border)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(AppTypography.code)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(AppSpacing.md)
            }
        }
        .background(AppColors.codeBackground, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
