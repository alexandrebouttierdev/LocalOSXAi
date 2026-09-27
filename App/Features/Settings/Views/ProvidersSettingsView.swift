import SwiftUI

/// Configuration of Ollama, LM Studio and custom OpenAI-compatible servers,
/// with the live status of each.
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
                    contextPresets
                }
                .help("Automatic reuses the size of an already loaded model, otherwise 8K. "
                      + "A different size makes Ollama reload the model.")
            } header: {
                providerHeader("Ollama", id: ProviderSettings.ollamaID, logo: ProviderSettings.ollamaLogo)
            }

            Section {
                Toggle("Enabled", isOn: $viewModel.lmStudioEnabled)
                urlField("Server URL", text: $viewModel.lmStudioURL, error: viewModel.validationErrors[.lmStudioURL])
                Text("The context length is the one chosen when the model was loaded in LM Studio.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            } header: {
                providerHeader("LM Studio", id: ProviderSettings.lmStudioID, logo: ProviderSettings.lmStudioLogo)
            }

            ForEach($viewModel.customServers) { $server in
                customServerSection($server)
            }

            Section {
                Button("Add OpenAI-Compatible Server…", systemImage: "plus", action: viewModel.addServer)
            } footer: {
                Text("For llama.cpp, vLLM, Jan, LocalAI and other servers implementing /v1/chat/completions. "
                     + "They list model names only, so declare what their models support.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
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
        .scrollContentBackground(.hidden)
        .alert(viewModel.error?.title ?? "", isPresented: Binding(get: { viewModel.error != nil },
                                                                  set: { if !$0 { viewModel.error = nil } })) {
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            Text([viewModel.error?.message, viewModel.error?.recoverySuggestion].compactMap { $0 }.joined(separator: "\n\n"))
        }
    }

    private func customServerSection(_ server: Binding<ProviderSettingsViewModel.ServerDraft>) -> some View {
        let draft = server.wrappedValue
        return Section {
            Toggle("Enabled", isOn: server.isEnabled)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("Name", text: server.name)
                    .autocorrectionDisabled()
                fieldError(viewModel.validationErrors[.serverName(draft.id)])
            }
            urlField("Server URL", text: server.url, error: viewModel.validationErrors[.serverURL(draft.id)],
                     apiKey: draft.apiKey)
            SecureField("API key", text: server.apiKey, prompt: Text("Optional"))
                .help("Sent as a bearer token. Stored in your Keychain only.")
            Toggle("Models support tool calling", isOn: server.supportsTools)
                .help("Turn off for servers that reject requests with tools. Tool calls are validated either way.")
            Picker("Context length", selection: server.contextTokens) {
                Text("Unknown (use 8K)").tag(Int?.none)
                contextPresets
            }
            .help("The context size the server was started with, such as llama-server -c.")
            HStack {
                Spacer()
                Button("Remove Server", role: .destructive) { viewModel.removeServer(id: draft.id) }
                    .accessibilityLabel("Remove \(draft.name)")
            }
        } header: {
            providerHeader(draft.name.isEmpty ? "Custom Server" : draft.name, id: draft.providerID, logo: nil)
        }
    }

    private var contextPresets: some View {
        ForEach(ProviderSettings.contextPresets, id: \.self) { tokens in
            Text("\(TokenCountFormatter.string(for: tokens)) tokens").tag(Int?.some(tokens))
        }
    }

    private func urlField(_ title: String, text: Binding<String>, error: String?, apiKey: String = "") -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            TextField(title, text: text)
                .textContentType(.URL)
                .autocorrectionDisabled()
            if let error {
                fieldError(error)
            } else if let warning = viewModel.privacyWarning(forURL: text.wrappedValue, apiKey: apiKey) {
                Label(warning, systemImage: "network")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.warning)
            }
        }
    }

    @ViewBuilder
    private func fieldError(_ error: String?) -> some View {
        if let error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.danger)
        }
    }

    private func providerHeader(_ title: String, id: ProviderID, logo: String?) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ProviderLogo(asset: logo, size: 14)
                .foregroundStyle(AppColors.textPrimary)
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
