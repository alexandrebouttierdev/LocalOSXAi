import SwiftUI

/// The integrated terminal: command history with streamed output above a
/// prompt. ↑/↓ browse history, ↩ runs, ⌃C stops.
struct TerminalView: View {
    @Bindable var viewModel: TerminalViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.entries.isEmpty {
                EmptyStateView(
                    systemImage: "terminal",
                    title: "Terminal",
                    message: "Run commands in \(viewModel.projectRoot.lastPathComponent). Output streams live; ⌃C stops."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                        ForEach(viewModel.entries) { entry in
                            TerminalEntryView(entry: entry)
                        }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.bottom)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .background(AppColors.codeBackground)
            }
            Divider().overlay(AppColors.border)
            prompt
        }
        .onAppear { isInputFocused = true }
        .alert(
            "Run this command?",
            isPresented: Binding(get: { viewModel.pendingConfirmation != nil }, set: { if !$0 { viewModel.dismissPending() } }),
            presenting: viewModel.pendingConfirmation
        ) { _ in
            Button("Run Anyway", role: .destructive) { viewModel.confirmPending() }
            Button("Cancel", role: .cancel) { viewModel.dismissPending() }
        } message: { confirmation in
            Text("\(confirmation.command)\n\n\(confirmation.reason)")
        }
    }

    private var prompt: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("❯")
                .font(AppTypography.code.weight(.bold))
                .foregroundStyle(AppColors.accentText)
                .accessibilityHidden(true)
            TextField("Command", text: $viewModel.input)
                .textFieldStyle(.plain)
                .font(AppTypography.code)
                .focused($isInputFocused)
                .onSubmit(viewModel.submit)
                .onKeyPress(.upArrow) { viewModel.previousCommand(); return .handled }
                .onKeyPress(.downArrow) { viewModel.nextCommand(); return .handled }
                .accessibilityLabel("Command")
            if viewModel.isRunning {
                Button("Stop", systemImage: "stop.fill", action: viewModel.stop)
                    .labelStyle(.iconOnly)
                    .appGlassButton()
                    .keyboardShortcut("c", modifiers: .control)
                    .help("Stop (⌃C)")
            }
            Button("Clear", systemImage: "trash", action: viewModel.clear)
                .labelStyle(.iconOnly)
                .buttonStyle(.subtle)
                .disabled(viewModel.entries.isEmpty)
                .help("Clear finished commands")
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: 44)
    }
}

private struct TerminalEntryView: View {
    let entry: TerminalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Text("❯ \(entry.command)")
                    .font(AppTypography.code.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .textSelection(.enabled)
                Spacer(minLength: AppSpacing.sm)
                status
            }
            if entry.droppedCharacters > 0 {
                Text("… \(entry.droppedCharacters) earlier characters not shown")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            ForEach(Array(entry.chunks.enumerated()), id: \.offset) { _, chunk in
                Text(chunk.text.trimmingCharacters(in: .newlines))
                    .font(AppTypography.code)
                    .foregroundStyle(chunk.stream == .stderr ? AppColors.danger : AppColors.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch entry.state {
        case .running:
            ProgressView().controlSize(.mini).accessibilityLabel("Running")
        case .finished(let exit):
            StatusBadge(
                title: exit.timedOut ? "Timed out" : "Exit \(exit.code) · \(Self.format(exit.duration))",
                systemImage: exit.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill",
                tone: exit.succeeded ? .success : .danger
            )
        case .cancelled:
            StatusBadge(title: "Stopped", systemImage: "stop.circle", tone: .neutral)
        case .failed(let reason):
            StatusBadge(title: "Failed", systemImage: "exclamationmark.triangle.fill", tone: .danger).help(reason)
        }
    }

    static func format(_ duration: Duration) -> String {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        return seconds < 10 ? String(format: "%.1f s", seconds) : "\(Int(seconds)) s"
    }
}
