import SwiftUI

/// A compact, expandable row describing one tool call in human terms
/// (“Read Makefile”), with its arguments and output available on demand.
struct ToolCallView: View {
    let call: ToolCallRecord
    /// Parsed once: the arguments of a `write_file` hold a whole file.
    private let presentation: ToolCallPresentation
    @State private var isExpanded = false
    @State private var isHovered = false

    /// The action's icon on a faint square of its hue, like Linear's issue icons.
    private static let iconSize: CGFloat = 22
    private static let iconTintOpacity = 0.14

    init(call: ToolCallRecord) {
        self.call = call
        presentation = ToolCallPresentation(call)
    }
    private var isAwaitingApproval: Bool { call.status == .awaitingApproval }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                header
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .accessibilityLabel("\(presentation.title), \(statusText)")
            .accessibilityHint(isExpanded ? "Collapses the details" : "Shows the details")

            if isExpanded {
                Divider().overlay(AppColors.border)
                detail
                    .transition(.opacity)
            }
        }
        .background(background, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(isAwaitingApproval ? AppColors.warning.opacity(0.35) : AppColors.border,
                              lineWidth: AppBorders.hairline)
        )
        .appAnimation(AppAnimation.quick, value: isHovered)
        .appAnimation(AppAnimation.standard, value: isExpanded)
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: presentation.systemImage)
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(Self.color(for: presentation.kind))
                .frame(width: Self.iconSize, height: Self.iconSize)
                .background(Self.color(for: presentation.kind).opacity(Self.iconTintOpacity),
                            in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                .accessibilityHidden(true)
            Text(presentation.title)
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let detail = presentation.detail {
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppSpacing.sm)
            if isAwaitingApproval {
                Text("Awaiting approval")
                    .font(AppTypography.caption.weight(.medium))
                    .foregroundStyle(AppColors.warning)
            } else if call.status.isFinished, let summary = call.summary, call.status != .succeeded {
                Text(summary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            statusIcon
                .frame(width: 16)
            Image(systemName: "chevron.right")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xxs)
        .frame(minHeight: 32)
        .contentShape(Rectangle())
    }

    /// The pending call is tinted so it is found at a glance next to the
    /// approval card; its state is also written out in the row.
    private var background: Color {
        if isAwaitingApproval { return AppColors.warning.opacity(0.06) }
        return isHovered || isExpanded ? AppColors.hover : .clear
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let summary = call.summary {
                Label(summary, systemImage: call.status == .succeeded ? "checkmark" : "info.circle")
                    .font(AppTypography.caption)
                    .foregroundStyle(call.status == .succeeded ? AppColors.success : AppColors.textSecondary)
            }
            labeled("Arguments", systemImage: "curlybraces", Self.highlightedJSON(call.argumentsJSON))
            if let output = call.output {
                labeled("Output", systemImage: "text.alignleft", AttributedString(output))
            }
        }
        .padding(AppSpacing.sm + AppSpacing.xxs)
    }

    /// Arguments, one key per line, colored like code (strings green,
    /// numbers yellow, booleans orange).
    private static func highlightedJSON(_ json: String) -> AttributedString {
        let pretty = (try? JSONSerialization.jsonObject(with: Data(json.utf8)))
            .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) }
            .flatMap { String(data: $0, encoding: .utf8) } ?? json
        var result = AttributedString()
        for (index, line) in pretty.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if index > 0 { result += AttributedString("\n") }
            for token in SyntaxHighlighter.tokens(in: String(line), language: .cLike) {
                var part = AttributedString(token.text)
                part.foregroundColor = switch token.kind {
                case .string: AppColors.Hue.green
                case .number: AppColors.Hue.yellow
                case .keyword: AppColors.Hue.orange
                default: AppColors.textSecondary
                }
                result += part
            }
        }
        return result
    }

    private static func color(for kind: ToolCallPresentation.Kind) -> Color {
        switch kind {
        case .read: AppColors.Hue.blue
        case .search: AppColors.Hue.purple
        case .edit: AppColors.Hue.orange
        case .write: AppColors.Hue.green
        case .command: AppColors.Hue.yellow
        case .git: AppColors.Hue.pink
        case .other: AppColors.textSecondary
        }
    }

    private func labeled(_ title: String, systemImage: String, _ value: AttributedString) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(title, systemImage: systemImage)
                .font(AppTypography.caption.weight(.medium))
                .foregroundStyle(AppColors.textTertiary)
            ScrollView {
                Text(value)
                    .font(AppTypography.code)
                    .foregroundStyle(AppColors.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.sm)
            }
            .frame(maxHeight: 220)
            .fixedSize(horizontal: false, vertical: true)
            .background(AppColors.codeBackground, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch call.status {
        case .running:
            ProgressView().controlSize(.mini)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.success)
                .transition(.symbolEffect(.appear))
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(AppColors.danger)
        case .denied:
            Image(systemName: "hand.raised.fill").foregroundStyle(AppColors.warning)
        case .awaitingApproval:
            Image(systemName: "hand.raised.circle").foregroundStyle(AppColors.warning)
                .symbolEffect(.pulse, options: .repeating)
        case .cancelled:
            Image(systemName: "stop.circle").foregroundStyle(AppColors.textTertiary)
        }
    }

    private var statusText: String {
        switch call.status {
        case .running: "running"
        case .succeeded: "succeeded"
        case .failed: "failed"
        case .denied: "denied"
        case .awaitingApproval: "awaiting approval"
        case .cancelled: "cancelled"
        }
    }
}
