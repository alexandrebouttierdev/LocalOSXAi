import SwiftUI

/// Per-project settings: which instruction files the agent reads and which
/// commands it may run without asking. Each change is saved at once.
struct ProjectSettingsView: View {
    let viewModel: ProjectsViewModel
    let projectID: Project.ID
    @State private var newPrefix = ""
    @Environment(\.dismiss) private var dismiss

    private var project: Project? { viewModel.project(id: projectID) }

    var body: some View {
        VStack(spacing: 0) {
            if let project {
                Form {
                    instructionsSection(project)
                    commandsSection(project)
                }
                .formStyle(.grouped)
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(AppSpacing.lg)
        }
        .frame(width: 520)
        .frame(minHeight: 420, idealHeight: 470)
        .navigationTitle("\(project?.name ?? "Project") Settings")
    }

    private func instructionsSection(_ project: Project) -> some View {
        Section {
            Toggle("Also read CLAUDE.md", isOn: Binding(
                get: { project.includesClaudeInstructions },
                set: { value in Task { await viewModel.setIncludesClaudeInstructions(value, for: projectID) } }
            ))
        } header: {
            Text("Instructions")
        } footer: {
            Text("AGENTS.md is always read. CLAUDE.md is added after it, from the next run.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func commandsSection(_ project: Project) -> some View {
        Section {
            Picker("Commands", selection: Binding(
                get: { project.commandRules.mode },
                set: { mode in Task { await viewModel.setCommandMode(mode, for: projectID) } }
            )) {
                Text("Ask for commands that change things").tag(CommandRules.Mode.standard)
                Text("Ask before every command").tag(CommandRules.Mode.askForEverything)
            }
            .pickerStyle(.radioGroup)

            LabeledContent("Always allowed") {
                if project.commandRules.allowedPrefixes.isEmpty {
                    Text("None").foregroundStyle(AppColors.textTertiary)
                }
            }
            ForEach(project.commandRules.allowedPrefixes, id: \.self) { prefix in
                HStack {
                    Text(prefix)
                        .font(AppTypography.code)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        Task { await viewModel.removeAllowedCommandPrefix(prefix, for: projectID) }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Ask again before running “\(prefix)”")
                    .accessibilityLabel("Remove \(prefix)")
                }
            }
            LabeledContent("Add a prefix") {
                HStack {
                    TextField("Add a prefix", text: $newPrefix, prompt: Text("npm install"))
                        .labelsHidden()
                        .font(AppTypography.code)
                        .multilineTextAlignment(.trailing)
                        .onSubmit(addPrefix)
                    Button("Add", action: addPrefix)
                        .disabled(CommandRules.normalizedPrefix(newPrefix) == nil)
                }
            }
        } header: {
            Text("Agent commands")
        } footer: {
            Text("Commands starting with an allowed prefix run without asking, e.g. “npm install” allows "
                 + "“npm install lodash”. Blocked commands (sudo, rm -rf outside the project…) stay blocked. "
                 + "Commands you type in the Terminal tab are not affected.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func addPrefix() {
        let prefix = newPrefix
        guard CommandRules.normalizedPrefix(prefix) != nil else { return }
        newPrefix = ""
        Task { await viewModel.addAllowedCommandPrefix(prefix, for: projectID) }
    }
}
