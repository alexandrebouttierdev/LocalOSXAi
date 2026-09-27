import SwiftUI

/// Generation settings for one model, saved as they change. Controls the
/// model cannot use are not shown: reasoning only for reasoning models. The
/// context length is chosen in the inspector's Context section
/// (`ContextLengthPicker`), next to the meter it changes.
struct ModelSettingsView: View {
    let viewModel: ModelsViewModel
    let model: AIModel
    /// Local while dragging; saved when the drag ends.
    @State private var temperature = 0.7

    private var settings: ModelSettings { viewModel.settings(for: model.id) }

    var body: some View {
        Form {
            Section {
                Toggle("Custom temperature", isOn: Binding(
                    get: { settings.temperature != nil },
                    set: { isCustom in save { $0.temperature = isCustom ? temperature : nil } }
                ))
                if settings.temperature != nil {
                    LabeledContent("Temperature") {
                        HStack {
                            Slider(value: $temperature, in: ModelSettings.temperatureRange, step: 0.1) { editing in
                                if !editing { save { $0.temperature = temperature } }
                            }
                            .frame(width: 140)
                            Text(temperature, format: .number.precision(.fractionLength(1)))
                                .monospacedDigit()
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            } footer: {
                Text("Lower is more focused, higher more varied. Off uses the model's default.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if model.supportsReasoning {
                Picker("Reasoning", selection: Binding(
                    get: { settings.reasoning },
                    set: { value in save { $0.reasoning = value } }
                )) {
                    Text("Default").tag(ReasoningEffort?.none)
                    ForEach(ReasoningEffort.allCases, id: \.self) { effort in
                        Text(effort.rawValue.capitalized).tag(ReasoningEffort?.some(effort))
                    }
                }
            }

            HStack {
                Spacer()
                Button("Restore Defaults") {
                    Task { await viewModel.updateSettings(settings.withDefaultGeneration, for: model.id) }
                }
                .disabled(!settings.hasGenerationOverrides)
            }
        }
        .formStyle(.grouped)
        .frame(width: 340)
        .onAppear { temperature = settings.temperature ?? temperature }
    }

    private func save(_ change: (inout ModelSettings) -> Void) {
        var next = settings
        change(&next)
        Task { await viewModel.updateSettings(next, for: model.id) }
    }
}
