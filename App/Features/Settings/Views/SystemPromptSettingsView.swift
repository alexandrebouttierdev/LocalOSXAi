import SwiftUI

/// Settings › System Prompt: the user's instructions, added to every run's
/// system prompt, and the built-in prompt they come after, read-only.
struct SystemPromptSettingsView: View {
    let agent: AgentSettingsViewModel
    @State private var showsBuiltIn = false

    var body: some View {
        Form {
            Section {
                TextEditor(text: instructions)
                    .font(AppTypography.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
                    .overlay(alignment: .topLeading) {
                        if agent.settings.customInstructions.isEmpty {
                            Text("For example: “Answer in French. Prefer small commits. Never add dependencies without asking.”")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textTertiary)
                                .padding(.top, AppSpacing.xxs)
                                .padding(.leading, AppSpacing.xs + AppSpacing.xxs)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Your instructions")
            } header: {
                Text("Your instructions")
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Sent with every message, in every project, after the built-in prompt and before the "
                         + "project's AGENTS.md. Applies to the next message. Keep it short: it uses context.")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: AppSpacing.md)
                    Text(count)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Clear") { agent.setCustomInstructions("") }
                        .disabled(agent.settings.customInstructions.isEmpty)
                }
                .font(AppTypography.caption)
            }

            Section {
                DisclosureGroup("Built-in prompt", isExpanded: $showsBuiltIn) {
                    Text(agent.builtInPrompt)
                        .font(AppTypography.code)
                        .foregroundStyle(AppColors.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, AppSpacing.xs)
                }
            } footer: {
                Text("What every run starts with. The project name, date and tool rules adapt to each run.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert(agent.error?.title ?? "", isPresented: Binding(get: { agent.error != nil }, set: { if !$0 { agent.error = nil } })) {
            Button("OK", role: .cancel) { agent.error = nil }
        } message: {
            Text(agent.error?.message ?? "")
        }
    }

    private var instructions: Binding<String> {
        Binding(get: { agent.settings.customInstructions }, set: { agent.setCustomInstructions($0) })
    }

    private var count: String {
        let used = agent.settings.customInstructions.count
        let tokens = TokenCountFormatter.string(for: TokenEstimator.estimate(agent.settings.customInstructions))
        return "\(used.formatted()) / \(AgentSettings.maxCustomInstructionsCharacters.formatted()) · ~\(tokens) tokens"
    }
}
