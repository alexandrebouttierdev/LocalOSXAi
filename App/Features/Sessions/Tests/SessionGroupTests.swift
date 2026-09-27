import Foundation
import Testing
@testable import LocalOSXAi

@Suite("SessionGroup")
struct SessionGroupTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// Noon, 20 days after the reference date, in UTC.
    private let now = Date(timeIntervalSinceReferenceDate: 20 * 86_400 + 43_200)

    private func session(daysAgo: Double, title: String) -> Session {
        Fixtures.session(projectID: UUID(), title: title, updatedAt: now.addingTimeInterval(-daysAgo * 86_400))
    }

    @Test("sessions are grouped by calendar day, in period order, keeping their order within a group")
    func grouping() {
        let sessions = [
            session(daysAgo: 0, title: "Now"), session(daysAgo: 0.4, title: "This morning"),
            session(daysAgo: 1, title: "Yesterday"), session(daysAgo: 3, title: "Monday"),
            session(daysAgo: 12, title: "Last month"), session(daysAgo: 40, title: "Ancient")
        ]
        let groups = SessionGroup.grouped(sessions, now: now, calendar: calendar)

        #expect(groups.map(\.period) == [.today, .yesterday, .previous7Days, .previous30Days, .older])
        #expect(groups.map(\.period.title) == ["Today", "Yesterday", "Previous 7 days", "Previous 30 days", "Older"])
        #expect(groups[0].sessions.map(\.title) == ["Now", "This morning"])
    }

    @Test("empty periods are left out, and no session means no group")
    func emptyPeriods() {
        #expect(SessionGroup.grouped([session(daysAgo: 2, title: "A")], now: now, calendar: calendar).map(\.period)
                == [.previous7Days])
        #expect(SessionGroup.grouped([], now: now, calendar: calendar).isEmpty)
    }
}
