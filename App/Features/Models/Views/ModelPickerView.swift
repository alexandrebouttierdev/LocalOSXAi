import SwiftUI

/// Model selector grouped by provider, so “Ollama · gpt-oss:20b” and
/// “LM Studio · qwen…” are never ambiguous, plus the selected model's
/// capabilities.
struct ModelPickerView: View {
    let viewModel: ModelsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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
                selectedLabel
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel("Model")
            .accessibilityValue(accessibilityValue)

            if let model = viewModel.selectedModel {
                capabilities(of: model)
            }
        }
    }

    private var selectedLabel: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let model = viewModel.selectedModel {
                    Text(viewModel.providerName(for: model.provider))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                    Text(model.displayName)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                } else {
                    Text(viewModel.isLoading ? "Loading models…" : "No model selected")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            Spacer(minLength: AppSpacing.xs)
            Image(systemName: "chevron.up.chevron.down")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
        .contentShape(Rectangle())
    }

    private func capabilities(of model: AIModel) -> some View {
        HStack(spacing: AppSpacing.xs) {
            if model.supportsTools { StatusBadge(title: "Tools", systemImage: "wrench.and.screwdriver", tone: .success) }
            if model.supportsReasoning { StatusBadge(title: "Reasoning", systemImage: "brain", tone: .accent) }
            if model.supportsVision { StatusBadge(title: "Vision", systemImage: "eye", tone: .accent) }
            StatusBadge(
                title: "\(TokenCountFormatter.string(for: model.contextWindow.effectiveTokens)) ctx",
                systemImage: "text.alignleft"
            )
            .help("Effective context window. Provider-advertised maximum: "
                  + (model.contextWindow.advertisedTokens.map { TokenCountFormatter.string(for: $0) } ?? "unknown"))
        }
    }

    private var accessibilityValue: String {
        guard let model = viewModel.selectedModel else { return "None" }
        return "\(model.displayName), from \(viewModel.providerName(for: model.provider))"
    }
}
