import SwiftUI

/// Prompt input with send/stop controls.
///
/// ↩ sends, ⌥↩ inserts a new line (standard behavior of a vertical
/// `TextField` on macOS), ⌘. stops a running agent.
struct ComposerView: View {
    @Binding var draft: String
    let isRunning: Bool
    let canSend: Bool
    let modelName: String?
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            TextField("Ask the agent…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .lineLimit(1...10)
                .focused($isFocused)
                .onSubmit(onSend)
                .accessibilityLabel("Message")

            HStack(spacing: AppSpacing.sm) {
                if let modelName {
                    Label(modelName, systemImage: "cpu")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: AppSpacing.sm)
                Text(isRunning ? "⌘. to stop" : "↩ send · ⌥↩ new line")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .accessibilityHidden(true)
                if isRunning {
                    Button("Stop", action: onStop)
                        .buttonStyle(.subtle)
                        .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("Send", action: onSend)
                        .buttonStyle(.primary)
                        .disabled(!canSend)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(isFocused ? AppColors.borderStrong : AppColors.border, lineWidth: AppBorders.hairline)
        )
        .frame(maxWidth: AppLayout.readableWidth)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.bottom, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .onAppear { isFocused = true }
    }
}
