import Foundation

/// When a message was sent, as the transcript shows it: the time today,
/// “Yesterday 14:32”, “12 Mar 14:32” this year, the year before that.
///
/// The calendar, time zone and locale are parameters so tests do not depend
/// on the machine they run on.
struct MessageTimeFormatter {
    var calendar = Calendar.current
    var locale = Locale.current

    func string(for date: Date, now: Date = Date()) -> String {
        let time = date.formatted(style.hour().minute())
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday \(time)"
        }
        let day = calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? date.formatted(style.day().month(.abbreviated))
            : date.formatted(style.day().month(.abbreviated).year())
        return "\(day) \(time)"
    }

    /// The tooltip: weekday, full date and time with seconds.
    func fullString(for date: Date) -> String {
        date.formatted(style.weekday(.wide).day().month(.wide).year().hour().minute().second())
    }

    private var style: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
