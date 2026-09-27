import SwiftUI

/// Settings › General: appearance and agent limits. Each change is saved at once.
struct GeneralSettingsView: View {
    @Bindable var agent: AgentSettingsViewModel
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                LabeledContent("Steps per run") {
                    Stepper(value: maxIterations, in: AgentSettings.maxIterationsRange, step: 5) {
                        Text("\(agent.settings.maxIterations)")
                            .monospacedDigit()
                    }
                }
                .help("Each step is one model call. The run pauses after this many; send “continue” to resume.")

                Picker("Tool timeout", selection: toolTimeout) {
                    ForEach(AgentSettings.toolTimeoutChoices, id: \.self) { seconds in
                        Text(Self.duration(seconds)).tag(seconds)
                    }
                }

                Toggle("Summarize earlier conversation", isOn: summarizesHistory)
                    .help("When a long session no longer fits the model's context, the model first summarizes "
                          + "its oldest messages. Off: they are dropped without a summary.")

                Picker("Summarize when context is", selection: compactThreshold) {
                    ForEach(AgentSettings.compactThresholdChoices, id: \.self) { percent in
                        Text("\(percent) % full").tag(percent)
                    }
                }
                .disabled(!agent.settings.summarizesHistory)
                .help("How full the model's context may be when a run starts before the oldest messages are "
                      + "summarized. Lower leaves more room for the run; higher keeps more messages word for word. "
                      + "Compact session, in the inspector, summarizes everything at any time.")
            } header: {
                Text("Agent")
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Applies to the next run. A run pauses after its steps; a tool that runs longer than "
                         + "the timeout is stopped and the model is told.")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: AppSpacing.md)
                    Button("Restore Defaults", action: agent.resetToDefaults)
                        .disabled(agent.settings == .defaults)
                }
                .font(AppTypography.caption)
            }

            Section {
                if agent.settings.showsNotifications {
                    notificationPermissionRow
                }
                Toggle("Show notifications", isOn: showsNotifications)
                    .help("When the agent answers, fails, pauses or waits for an approval while you are in another "
                          + "app, session or tab. Click the notification to open the session.")
                Toggle("Play a sound", isOn: playsSound)
                    .help("At the same moments, also while you are looking at the session.")
                HStack {
                    Spacer()
                    Button("Send Test Notification") { Task { await agent.sendTestNotification() } }
                        .help("Shows a notification now, to check that macOS displays it (Focus, permission, banners).")
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("While you look at a session, only the sound plays. A Focus mode can hide notifications.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .task { await agent.refreshNotificationPermission() }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert(agent.error?.title ?? "", isPresented: Binding(get: { agent.error != nil }, set: { if !$0 { agent.error = nil } })) {
            Button("OK", role: .cancel) { agent.error = nil }
        } message: {
            Text(agent.error?.message ?? "")
        }
    }

    private var maxIterations: Binding<Int> {
        Binding(get: { agent.settings.maxIterations }, set: { agent.setMaxIterations($0) })
    }

    private var summarizesHistory: Binding<Bool> {
        Binding(get: { agent.settings.summarizesHistory }, set: { agent.setSummarizesHistory($0) })
    }

    private var compactThreshold: Binding<Int> {
        Binding(get: { agent.settings.compactThresholdPercent }, set: { agent.setCompactThresholdPercent($0) })
    }

    /// Whether macOS lets the app notify, with the way to fix it: a status
    /// dot and words, never the color alone.
    @ViewBuilder
    private var notificationPermissionRow: some View {
        switch agent.notificationPermission {
        case .allowed:
            LabeledContent("macOS permission") {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.success)
            }
        case .denied:
            LabeledContent("macOS permission") {
                HStack(spacing: AppSpacing.sm) {
                    Label("Off in System Settings", systemImage: "xmark.circle.fill")
                        .foregroundStyle(AppColors.danger)
                    Button("Open System Settings…", action: agent.openNotificationSettings)
                }
            }
        case .notDetermined:
            LabeledContent("macOS permission") {
                HStack(spacing: AppSpacing.sm) {
                    Label("Not asked yet", systemImage: "questionmark.circle")
                        .foregroundStyle(AppColors.warning)
                    Button("Allow Notifications…") { Task { await agent.allowNotifications() } }
                }
            }
        case nil:
            EmptyView()
        }
    }

    private var showsNotifications: Binding<Bool> {
        Binding(get: { agent.settings.showsNotifications }, set: { agent.setShowsNotifications($0) })
    }

    private var playsSound: Binding<Bool> {
        Binding(get: { agent.settings.playsSound }, set: { agent.setPlaysSound($0) })
    }

    private var toolTimeout: Binding<Int> {
        Binding(get: { agent.settings.toolTimeoutSeconds }, set: { agent.setToolTimeoutSeconds($0) })
    }

    private static func duration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) seconds" : (seconds == 60 ? "1 minute" : "\(seconds / 60) minutes")
    }
}
