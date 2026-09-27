import Foundation

/// Sessions of one period, as the sidebar groups them (like Claude Code):
/// Today, Yesterday, Previous 7 days, Previous 30 days, Older.
struct SessionGroup: Identifiable, Hashable, Sendable {
    enum Period: Int, CaseIterable, Sendable {
        case today, yesterday, previous7Days, previous30Days, older

        var title: String {
            switch self {
            case .today: "Today"
            case .yesterday: "Yesterday"
            case .previous7Days: "Previous 7 days"
            case .previous30Days: "Previous 30 days"
            case .older: "Older"
            }
        }
    }

    let period: Period
    let sessions: [Session]

    var id: Period { period }

    /// Groups sessions by the calendar day of their last update, relative to
    /// `now`. Empty periods are left out; sessions keep their order.
    static func grouped(_ sessions: [Session], now: Date, calendar: Calendar = .current) -> [SessionGroup] {
        let today = calendar.startOfDay(for: now)
        let buckets = Dictionary(grouping: sessions) { session in
            period(of: calendar.startOfDay(for: session.updatedAt), today: today, calendar: calendar)
        }
        return Period.allCases.compactMap { period in
            buckets[period].map { SessionGroup(period: period, sessions: $0) }
        }
    }

    private static func period(of day: Date, today: Date, calendar: Calendar) -> Period {
        let days = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        switch days {
        case ...0: return .today
        case 1: return .yesterday
        case 2...7: return .previous7Days
        case 8...30: return .previous30Days
        default: return .older
        }
    }
}
