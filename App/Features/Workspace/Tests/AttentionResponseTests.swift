import Foundation
import Testing
@testable import LocalOSXAi

@Suite("AttentionResponse")
struct AttentionResponseTests {
    private let sessionID = UUID()

    private func response(_ attention: AgentAttention = .answered(preview: "Done."), visible: Bool,
                          notifications: Bool = true, sound: Bool = true) -> AttentionResponse {
        AttentionResponse.response(to: attention, session: NotifiedSession(id: sessionID, title: "Fix login", projectName: "App"),
                                   isSessionVisible: visible,
                                   preferences: NotificationPreferences(showsNotifications: notifications, playsSound: sound))
    }

    @Test("a session the user is not looking at gets a notification, with the sound if chosen")
    func notification() {
        #expect(response(visible: false) == .notification(UserNotification(
            sessionID: sessionID, title: "Fix login", subtitle: "App", body: "Done.", playsSound: true
        )))
        guard case .notification(let silent) = response(visible: false, sound: false) else {
            Issue.record("Expected a notification")
            return
        }
        #expect(!silent.playsSound)
    }

    @Test("a visible session only gets the sound, and nothing when it is off")
    func visible() {
        #expect(response(visible: true) == .sound)
        #expect(response(visible: true, sound: false) == AttentionResponse.none)
    }

    @Test("with notifications off, the sound still plays unless it is off too")
    func notificationsOff() {
        #expect(response(visible: false, notifications: false) == .sound)
        #expect(response(visible: false, notifications: false, sound: false) == AttentionResponse.none)
    }

    @Test("the body says what happened, with a short, single-line preview of the answer")
    func bodies() {
        #expect(AttentionResponse.body(for: .answered(preview: "Line one\n\n  line two")) == "Line one line two")
        #expect(AttentionResponse.body(for: .answered(preview: " \n")) == "The agent finished.")
        let long = AttentionResponse.body(for: .answered(preview: String(repeating: "a", count: 500)))
        #expect(long.count == UserNotification.previewLength)
        #expect(long.hasSuffix("…"))
        #expect(AttentionResponse.body(for: .failed(message: "Server down.")) == "The run failed: Server down.")
        #expect(AttentionResponse.body(for: .approvalNeeded(summary: "Run make")) == "Approval needed: Run make")
        #expect(AttentionResponse.body(for: .pausedAtStepLimit).contains("step limit"))
    }
}
