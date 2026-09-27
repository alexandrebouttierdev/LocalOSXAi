import Foundation

/// How the app tells the user that a session needs them.
enum AttentionResponse: Hashable, Sendable {
    case none
    /// The user is looking at the session: a sound is enough.
    case sound
    case notification(UserNotification)

    /// A notification only when the user is not looking at the session (the
    /// app is in the background, or another session, tab or settings is
    /// shown); otherwise, at most a sound.
    static func response(to attention: AgentAttention, sessionID: UUID, sessionTitle: String, projectName: String,
                         isSessionVisible: Bool, preferences: NotificationPreferences) -> AttentionResponse {
        if !isSessionVisible, preferences.showsNotifications {
            return .notification(UserNotification(sessionID: sessionID, title: sessionTitle, subtitle: projectName,
                                                  body: body(for: attention), playsSound: preferences.playsSound))
        }
        return preferences.playsSound ? .sound : .none
    }

    static func body(for attention: AgentAttention) -> String {
        switch attention {
        case .answered(let preview):
            let text = preview.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !text.isEmpty else { return "The agent finished." }
            return text.count > UserNotification.previewLength
                ? String(text.prefix(UserNotification.previewLength - 1)) + "…"
                : text
        case .pausedAtStepLimit:
            return "The agent paused after its step limit. Send “continue” to resume."
        case .failed(let message):
            return "The run failed: \(message)"
        case .approvalNeeded(let summary):
            return "Approval needed: \(summary)"
        }
    }
}
