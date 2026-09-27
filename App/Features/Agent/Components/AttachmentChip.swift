import SwiftUI

/// A file attached to a message: icon, name and size, with a remove button
/// while it is still in the draft. Its path is in the tooltip.
struct AttachmentChip: View {
    let attachment: MessageAttachment
    /// Set while the file is in the composer; `nil` in the transcript.
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
            Image(systemName: "doc.text")
                .foregroundStyle(AppColors.accentText)
                .accessibilityHidden(true)
            Text(attachment.name)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(size)
                .foregroundStyle(AppColors.textTertiary)
                .monospacedDigit()
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(AppTypography.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.textTertiary)
                .help("Remove \(attachment.name)")
                .accessibilityLabel("Remove \(attachment.name)")
            }
        }
        .font(AppTypography.callout)
        .padding(.horizontal, AppSpacing.sm)
        .frame(height: AppLayout.rowHeight - AppSpacing.xs)
        .background(AppColors.accentSubtle, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
        .help(attachment.isTruncated
              ? "\(attachment.path)\nOnly the first \(MessageAttachment.maxCharacters) characters are sent."
              : attachment.path)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Attached file \(attachment.name), \(size)\(attachment.isTruncated ? ", truncated" : "")")
    }

    private var size: String {
        ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file)
    }
}
