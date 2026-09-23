import SwiftUI

/// Configuration of Ollama and LM Studio, with the live status of each.
struct ProvidersSettingsView: View {
    @Bindable var viewModel: ProviderSettingsViewModel
    let models: ModelsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $viewModel.ollamaEnabled)
                urlField("Server URL", text: $viewModel.ollamaURL, error: viewModel.validationErrors[.ollamaURL])
                Picker("Context length", selection: $viewModel.ollamaContextTokens) {
                    Text("Automatic").tag(Int?.none)
                    ForEach(ProviderSettings.contextPresets, id: \.self) { tokens in
                        Text("\(TokenCountFormatter.string(for: tokens)) tokens").tag(Int?.some(tokens))
                    }
                }
                .help("Automatic reuses the size of an already loaded model, otherwise 8K. "
                      + "A different size makes Ollama reload the model.")
            } header: {
                providerHeader("Ollama", id: ProviderSettings.ollamaID)
            }

            Section {
                Toggle("Enabled", isOn: $viewModel.lmStudioEnabled)
                urlField("Server URL", text: $viewModel.lmStudioURL, error: viewModel.validationErrors[.lmStudioURL])
                Text("The context length is the one chosen when the model was loaded in LM Studio.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            } header: {
                providerHeader("LM Studio", id: ProviderSettings.lmStudioID)
            }

            Section("Network") {
                LabeledContent("Timeout without response") {
                    Stepper(value: $viewModel.idleTimeoutSeconds, in: ProviderSettings.idleTimeoutRange, step: 30) {
                        Text("\(Int(viewModel.idleTimeoutSeconds)) s").monospacedDigit()
                    }
                }
                .help("Loading a large model can take minutes before the first token.")
            }

            Section {
                HStack {
                    Button("Restore Defaults", action: viewModel.restoreDefaults)
                    Spacer()
                    Button("Revert", action: viewModel.revert)
                        .disabled(!viewModel.hasChanges)
                    Button("Apply") { Task { await viewModel.apply() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!viewModel.hasChanges || viewModel.isApplying)
                }
            }
        }
        .formStyle(.grouped)
        .padding(AppSpacing.sm)
    }

    private func urlField(_ title: String, text: Binding<String>, error: String?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            TextField(title, text: text)
                .textContentType(.URL)
                .autocorrectionDisabled()
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
            }
        }
    }

    private func providerHeader(_ title: String, id: ProviderID) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let entry = models.catalog.first(where: { $0.id == id }) {
                switch entry.status {
                case .available(let list):
                    StatusBadge(title: "Connected · \(list.count) model\(list.count == 1 ? "" : "s")",
                                systemImage: "checkmark.circle.fill", tone: .success)
                case .unavailable(let reason):
                    StatusBadge(title: "Unavailable", systemImage: "xmark.circle.fill", tone: .danger)
                        .help(reason)
                }
            } else {
                StatusBadge(title: "Disabled", systemImage: "minus.circle", tone: .neutral)
            }
        }
    }
}
