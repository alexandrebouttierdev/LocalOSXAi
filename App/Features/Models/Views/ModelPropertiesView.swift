import SwiftUI

/// The inspector's model properties, like Linear's issue properties: the
/// model, its context length, temperature and reasoning, each a menu on its
/// row that applies to the next message, and what the model can do.
struct ModelPropertiesView: View {
    let viewModel: ModelsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertyRow(label: "Model") { modelMenu }
            if let model = viewModel.selectedModel {
                PropertyRow(label: "Context") { context(for: model) }
                PropertyRow(label: "Temperature") { temperatureMenu(for: model) }
                if model.supportsReasoning {
                    PropertyRow(label: "Reasoning") { reasoningMenu(for: model) }
                }
                PropertyRow(label: "Abilities") { abilities(of: model) }
            } else if viewModel.hasNoReachableProvider {
                Text("No model server is reachable. Start Ollama or LM Studio, then choose Refresh Models.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.xs)
            }
        }
    }

    // MARK: Model

    /// Models grouped by provider, so “Ollama · gpt-oss:20b” and
    /// “LM Studio · qwen…” are never ambiguous.
    private var modelMenu: some View {
        Menu {
            ForEach(viewModel.catalog) { group in
                Section(group.provider.displayName) {
                    switch group.status {
                    case .available(let models) where models.isEmpty:
                        Text("No models installed")
                    case .available(let models):
                        ForEach(models) { model in
                            Toggle(model.displayName, isOn: Binding(
                                get: { model.id == viewModel.selectedModelID },
                                set: { if $0 { viewModel.select(model.id) } }
                            ))
                        }
                    case .unavailable(let reason):
                        Text(reason)
                    }
                }
            }
            Divider()
            Button("Refresh Models") {
                Task { await viewModel.refresh() }
            }
        } label: {
            if let model = viewModel.selectedModel {
                PropertyValue(text: model.displayName) {
                    ProviderLogo(asset: viewModel.provider(for: model.provider)?.logo, size: 14)
                }
            } else {
                PropertyValue(viewModel.isLoading ? "Loading models…" : "Choose a model", systemImage: "cpu",
                              isPlaceholder: true)
            }
        }
        .propertyMenuStyle()
        .help(viewModel.selectedModel.map { "\(viewModel.providerName(for: $0.provider)) · \($0.displayName)" } ?? "Choose a model")
        .accessibilityLabel("Model")
        .accessibilityValue(viewModel.selectedModel.map { "\($0.displayName), from \(viewModel.providerName(for: $0.provider))" }
                            ?? "None")
    }

    // MARK: Generation

    /// A menu for providers that allocate the context per request (Ollama);
    /// otherwise the fixed size, with where it is set.
    @ViewBuilder
    private func context(for model: AIModel) -> some View {
        let tokens = "\(TokenCountFormatter.string(for: viewModel.effectiveContextTokens(for: model))) tokens"
        if viewModel.canSetContext(for: model.id) {
            let chosen = viewModel.settings(for: model.id).contextTokens
            Menu {
                choice("Automatic (\(TokenCountFormatter.string(for: viewModel.automaticContextTokens(for: model))))",
                       isSelected: chosen == nil) {
                    Task { await viewModel.setContextTokens(nil, for: model) }
                }
                Divider()
                ForEach(viewModel.contextChoices(for: model), id: \.self) { size in
                    choice("\(TokenCountFormatter.string(for: size)) tokens", isSelected: chosen == size) {
                        Task { await viewModel.setContextTokens(size, for: model) }
                    }
                }
            } label: {
                PropertyValue(tokens, systemImage: "gauge.medium")
            }
            .propertyMenuStyle()
            .help("Applies to the next message. A size other than the loaded one makes "
                  + "\(viewModel.providerName(for: model.provider)) reload the model, which can take a while.")
        } else {
            PropertyValue(tokens, systemImage: "gauge.medium", isInteractive: false)
                .help("\(viewModel.providerName(for: model.provider)) sets the context when it loads the model: "
                      + "change it there (for a custom server, in Settings › Providers).")
        }
    }

    private func temperatureMenu(for model: AIModel) -> some View {
        let temperature = viewModel.settings(for: model.id).temperature
        return Menu {
            choice("Default", isSelected: temperature == nil) {
                Task { await viewModel.setTemperature(nil, for: model) }
            }
            Divider()
            ForEach(ModelSettings.temperatureChoices, id: \.self) { value in
                choice(Self.format(value), isSelected: temperature == value) {
                    Task { await viewModel.setTemperature(value, for: model) }
                }
            }
        } label: {
            PropertyValue(temperature.map(Self.format) ?? "Default", systemImage: "thermometer.medium",
                          isPlaceholder: temperature == nil)
        }
        .propertyMenuStyle()
        .help("Lower is more focused, higher more varied. Default uses the model's own.")
    }

    private func reasoningMenu(for model: AIModel) -> some View {
        let reasoning = viewModel.settings(for: model.id).reasoning
        return Menu {
            choice("Default", isSelected: reasoning == nil) {
                Task { await viewModel.setReasoning(nil, for: model) }
            }
            Divider()
            ForEach(ReasoningEffort.allCases, id: \.self) { effort in
                choice(effort.rawValue.capitalized, isSelected: reasoning == effort) {
                    Task { await viewModel.setReasoning(effort, for: model) }
                }
            }
        } label: {
            PropertyValue(reasoning?.rawValue.capitalized ?? "Default", systemImage: "brain", isPlaceholder: reasoning == nil)
        }
        .propertyMenuStyle()
        .help("How much the model thinks before answering.")
    }

    /// What the provider declares; quiet text, no colored chips.
    @ViewBuilder
    private func abilities(of model: AIModel) -> some View {
        let abilities = [
            model.supportsTools ? ("Tools", "wrench.and.screwdriver") : nil,
            model.supportsReasoning ? ("Reasoning", "brain") : nil,
            model.supportsVision ? ("Vision", "eye") : nil
        ].compactMap { $0 }
        if abilities.isEmpty {
            Text("Chat only")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
        } else {
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(abilities, id: \.0) { title, systemImage in
                    Label(title, systemImage: systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.xs + AppSpacing.xxs)
            .help("As declared by the provider. Every tool call is still validated.")
        }
    }

    // MARK: Helpers

    /// A menu item with a check mark on the current value.
    private func choice(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private static func format(_ temperature: Double) -> String {
        temperature.formatted(.number.precision(.fractionLength(1)))
    }
}
