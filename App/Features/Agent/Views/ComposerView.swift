import SwiftUI

/// Floating glass composer: prompt field, model label and a round send/stop
/// button.
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
                actionButton
            }
        }
        .padding(.leading, AppSpacing.lg)
        .padding(.trailing, AppSpacing.sm + AppSpacing.xxs)
        .padding(.vertical, AppSpacing.md)
        .appGlass(in: RoundedRectangle(cornerRadius: AppRadius.composer, style: .continuous))
        .onAppear { isFocused = true }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isRunning {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 18, height: 18)
            }
            .appGlassButton()
            .buttonBorderShape(.circle)
            .keyboardShortcut(".", modifiers: .command)
            .help("Stop (⌘.)")
            .accessibilityLabel("Stop")
        } else {
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 18, height: 18)
            }
            .appGlassButton(prominent: true)
            .buttonBorderShape(.circle)
            .disabled(!canSend)
            .help("Send (↩)")
            .accessibilityLabel("Send")
        }
    }
}
