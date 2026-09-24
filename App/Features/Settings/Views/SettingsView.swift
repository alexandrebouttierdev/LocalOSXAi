import SwiftUI

/// The Settings window (⌘,).
struct SettingsView: View {
    let agent: AgentSettingsViewModel
    let providers: ProviderSettingsViewModel
    let models: ModelsViewModel

    var body: some View {
        TabView {
            GeneralSettingsView(agent: agent)
                .tabItem { Label("General", systemImage: "gearshape") }
            ProvidersSettingsView(viewModel: providers, models: models)
                .tabItem { Label("Providers", systemImage: "cpu") }
        }
        .frame(width: 560)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var agent: AgentSettingsViewModel
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                LabeledContent("Steps per run") {
                    Stepper(value: maxIterations, in: AgentSettings.maxIterationsRange, step: 5) {
                        Text("\(agent.settings.maxIterations)")
                            .monospacedDigit()
                    }
                }
                .help("Each step is one model call. The run pauses after this many; send “continue” to resume.")

                Picker("Tool timeout", selection: toolTimeout) {
                    ForEach(AgentSettings.toolTimeoutChoices, id: \.self) { seconds in
                        Text(Self.duration(seconds)).tag(seconds)
                    }
                }
            } header: {
                Text("Agent")
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Applies to the next run. A run pauses after its steps; a tool that runs longer than "
                         + "the timeout is stopped and the model is told.")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: AppSpacing.md)
                    Button("Restore Defaults", action: agent.resetToDefaults)
                        .disabled(agent.settings == .defaults)
                }
                .font(AppTypography.caption)
            }
        }
        .formStyle(.grouped)
        .padding(AppSpacing.sm)
        .alert(agent.error?.title ?? "", isPresented: Binding(get: { agent.error != nil }, set: { if !$0 { agent.error = nil } })) {
            Button("OK", role: .cancel) { agent.error = nil }
        } message: {
            Text(agent.error?.message ?? "")
        }
    }

    private var maxIterations: Binding<Int> {
        Binding(get: { agent.settings.maxIterations }, set: { agent.setMaxIterations($0) })
    }

    private var toolTimeout: Binding<Int> {
        Binding(get: { agent.settings.toolTimeoutSeconds }, set: { agent.setToolTimeoutSeconds($0) })
    }

    private static func duration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) seconds" : (seconds == 60 ? "1 minute" : "\(seconds / 60) minutes")
    }
}
