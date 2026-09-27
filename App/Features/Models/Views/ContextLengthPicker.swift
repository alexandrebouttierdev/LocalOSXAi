import SwiftUI

/// The selected model's context length, chosen from the inspector.
///
/// Only providers that allocate the context per request (Ollama) can change
/// it here. Others fix it when they load the model, so the size is shown with
/// where it comes from.
struct ContextLengthPicker: View {
    let viewModel: ModelsViewModel
    let model: AIModel

    var body: some View {
        if viewModel.canSetContext(for: model.id) {
            Picker(selection: selection) {
                Text("Automatic (\(TokenCountFormatter.string(for: viewModel.automaticContextTokens(for: model))))")
                    .tag(Int?.none)
                Divider()
                ForEach(viewModel.contextChoices(for: model), id: \.self) { tokens in
                    Text("\(TokenCountFormatter.string(for: tokens)) tokens").tag(Int?.some(tokens))
                }
            } label: {
                Text("Context length")
            }
            .pickerStyle(.menu)
            .font(AppTypography.callout)
            .help("Applies to the next message. A size other than the loaded one makes "
                  + "\(viewModel.providerName(for: model.provider)) reload the model, which can take a while.")
        } else {
            LabeledContent("Context length") {
                Text("\(TokenCountFormatter.string(for: viewModel.effectiveContextTokens(for: model))) tokens")
                    .monospacedDigit()
            }
            .font(AppTypography.callout)
            .help("\(viewModel.providerName(for: model.provider)) sets the context when it loads the model: "
                  + "change it there (for a custom server, in Settings › Providers).")
        }
    }

    private var selection: Binding<Int?> {
        Binding(
            get: { viewModel.settings(for: model.id).contextTokens },
            set: { tokens in Task { await viewModel.setContextTokens(tokens, for: model) } }
        )
    }
}
