import Foundation
import Testing
@testable import LocalOSXAi

@Suite("MessageTimeFormatter")
struct MessageTimeFormatterTests {
    private let formatter: MessageTimeFormatter = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return MessageTimeFormatter(calendar: calendar, locale: Locale(identifier: "en_GB"))
    }()

    private func date(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }

    @Test("today shows the time, yesterday says so, older days add the date and, last year, the year")
    func relativeDays() throws {
        let now = try date("2026-09-27T16:00:00Z")
        let today = formatter.string(for: try date("2026-09-27T14:32:00Z"), now: now)
        #expect(today == "14:32")
        #expect(formatter.string(for: try date("2026-09-26T09:05:00Z"), now: now) == "Yesterday 09:05")

        let thisYear = formatter.string(for: try date("2026-03-12T14:32:00Z"), now: now)
        #expect(thisYear.hasPrefix("12 Mar"))
        #expect(thisYear.hasSuffix("14:32"))
        #expect(!thisYear.contains("2026"))

        #expect(formatter.string(for: try date("2025-03-12T14:32:00Z"), now: now).contains("2025"))
    }

    @Test("the tooltip has the weekday, the full date and the seconds")
    func full() throws {
        let text = formatter.fullString(for: try date("2026-09-27T14:32:05Z"))
        #expect(text.contains("Sunday"))
        #expect(text.contains("September"))
        #expect(text.contains("14:32:05"))
    }
}
