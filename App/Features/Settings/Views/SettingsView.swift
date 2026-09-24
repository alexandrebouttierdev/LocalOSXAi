import SwiftUI

/// The Settings window (⌘,).
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
        }
        .formStyle(.grouped)
        .padding(AppSpacing.sm)
    }
}
