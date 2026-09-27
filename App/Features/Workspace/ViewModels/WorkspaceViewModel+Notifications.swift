import Foundation

/// Notifications and sounds when a session needs the user (docs/ui/notifications.md).
extension WorkspaceViewModel {
    /// Asks for permission at launch while notifications are on, so the macOS
    /// prompt shows while the user is here, not when a run ends unseen.
    func prepareNotifications() {
        guard let notifier = services.notifier, services.notificationPreferences().showsNotifications else { return }
        Task { _ = await notifier.requestPermission() }
    }

    /// The user sees the session's conversation right now.
    func isVisible(_ sessionID: Session.ID) -> Bool {
        isAppActive && !isSettingsPresented && selectedTab == .agent && selectedSessionID == sessionID
    }

    /// - Parameter fallbackTitle: the title when the agent was opened, for a
    ///   session of another project, which `sessions` does not list.
    func notify(_ attention: AgentAttention, sessionID: Session.ID, projectID: Project.ID, fallbackTitle: String) {
        guard let notifier = services.notifier else { return }
        let title = sessions.session(id: sessionID)?.title ?? fallbackTitle
        let response = AttentionResponse.response(
            to: attention, sessionID: sessionID, sessionTitle: title,
            projectName: projects.project(id: projectID)?.name ?? "",
            isSessionVisible: isVisible(sessionID), preferences: services.notificationPreferences()
        )
        switch response {
        case .none: break
        case .sound: notifier.playSound()
        case .notification(let notification): Task { await notifier.post(notification) }
        }
    }

    /// Shows a session from anywhere: another project, the settings screen
    /// or another tab. Used when the user clicks its notification.
    func openSession(_ sessionID: Session.ID) async {
        closeSettings()
        if sessions.session(id: sessionID) == nil {
            guard let session = await sessions.fullSession(id: sessionID) else { return }
            await selectProject(session.projectID)
        }
        await selectSession(sessionID)
    }
}
