import SwiftUI
import UniformTypeIdentifiers

/// Floating composer: attached files, prompt field, attach button, model
/// label and a square send/stop button, on a raised opaque surface.
///
/// ↩ sends, ⌥↩ inserts a new line (standard behavior of a vertical
/// `TextField` on macOS), ⌘. stops a running agent. Files are attached with
/// the paperclip or by dropping them on the conversation.
struct ComposerView: View {
    @Binding var draft: String
    let isRunning: Bool
    let canSend: Bool
    let modelName: String?
    var attachments: [MessageAttachment] = []
    var attachmentError: UserFacingError?
    /// False hides the paperclip.
    var canAttach = false
    /// Files are being dragged over the conversation.
    var isDropTargeted = false
    var onAttach: ([URL]) -> Void = { _ in }
    var onRemoveAttachment: (MessageAttachment.ID) -> Void = { _ in }
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if !attachments.isEmpty {
                FlowLayout(spacing: AppSpacing.xs) {
                    ForEach(attachments) { attachment in
                        AttachmentChip(attachment: attachment, onRemove: { onRemoveAttachment(attachment.id) })
                    }
                }
            }
            if let attachmentError {
                Label([attachmentError.message, attachmentError.recoverySuggestion].compactMap { $0 }.joined(separator: " "),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("Ask the agent…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .lineLimit(1...10)
                .focused($isFocused)
                .onSubmit(onSend)
                .accessibilityLabel("Message")

            HStack(spacing: AppSpacing.sm) {
                if canAttach {
                    Button { isImporting = true } label: {
                        Image(systemName: "paperclip")
                    }
                    .buttonStyle(.ghostIcon)
                    .help("Attach files (or drop them on the conversation)")
                    .accessibilityLabel("Attach files")
                }
                if let modelName {
                    Label(modelName, systemImage: "cpu")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: AppSpacing.sm)
                Text(isDropTargeted ? "Drop to attach" : (isRunning ? "⌘. to stop" : "↩ send · ⌥↩ new line"))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .accessibilityHidden(true)
                actionButton
            }
        }
        .padding(.leading, AppSpacing.md + AppSpacing.xxs)
        .padding(.trailing, AppSpacing.sm)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .appFloating(in: RoundedRectangle(cornerRadius: AppRadius.composer, style: .continuous))
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: AppRadius.composer, style: .continuous)
                    .strokeBorder(AppColors.accent, lineWidth: AppBorders.focus)
            }
        }
        .onAppear { isFocused = true }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let files) = result { onAttach(files) }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isRunning {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.icon())
            .keyboardShortcut(".", modifiers: .command)
            .help("Stop (⌘.)")
            .accessibilityLabel("Stop")
        } else {
            Button(action: onSend) {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.icon(prominent: true))
            .disabled(!canSend)
            .help("Send (↩)")
            .accessibilityLabel("Send")
        }
    }
}
