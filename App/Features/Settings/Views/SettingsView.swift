import SwiftUI

/// The Settings window (⌘,).
///
/// Only appearance is configurable in Phase 1. Provider endpoints, agent
/// limits and permission policy settings arrive with the phases that
/// implement them (see README roadmap); their absence is stated explicitly.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 480)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Providers") {
                Text("Ollama and LM Studio configuration arrives in Phase 2.")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Agent") {
                Text("Iteration limits, timeouts and permissions arrive in Phases 3 and 4.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(AppSpacing.sm)
    }
}
