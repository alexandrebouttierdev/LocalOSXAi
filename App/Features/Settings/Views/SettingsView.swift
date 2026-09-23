import SwiftUI

/// The Settings window (⌘,).
///
/// Agent limits and the permission policy arrive with Phases 3 and 4; their
/// absence is stated in the General tab rather than hidden.
struct SettingsView: View {
    let providers: ProviderSettingsViewModel
    let models: ModelsViewModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ProvidersSettingsView(viewModel: providers, models: models)
                .tabItem { Label("Providers", systemImage: "cpu") }
        }
        .frame(width: 560)
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

            LabeledContent("Agent") {
                Text("Iteration limits, timeouts and permissions arrive in Phases 3 and 4.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(AppSpacing.sm)
    }
}
