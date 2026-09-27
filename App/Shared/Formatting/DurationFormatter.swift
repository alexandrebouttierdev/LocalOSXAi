import Foundation

/// Elapsed times as the interface shows them: seconds under a minute, then
/// minutes and seconds, then hours and minutes (“12 s”, “2:05 min”, “1:05 h”).
///
/// One formatter for every timer (turns, loaders, commands), so a long run
/// reads the same everywhere.
enum DurationFormatter {
    /// - Parameter precise: tenths under a minute, for finished durations.
    ///   Live timers use whole seconds so they do not flicker.
    static func string(_ seconds: TimeInterval, precise: Bool = false) -> String {
        let value = max(seconds, 0)
        if value < 60 {
            return precise ? String(format: "%.1f s", value) : "\(Int(value)) s"
        }
        let total = Int(value)
        if total < 3_600 {
            return String(format: "%d:%02d min", total / 60, total % 60)
        }
        return String(format: "%d:%02d h", total / 3_600, total % 3_600 / 60)
    }

    /// For VoiceOver: “2 minutes 5 seconds”, “1 hour 5 minutes”.
    static func spoken(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded())
        let (hours, minutes, rest) = (total / 3_600, total % 3_600 / 60, total % 60)
        let parts = hours > 0
            ? [unit(hours, "hour"), minutes > 0 ? unit(minutes, "minute") : nil]
            : [minutes > 0 ? unit(minutes, "minute") : nil, rest > 0 || minutes == 0 ? unit(rest, "second") : nil]
        return parts.compactMap { $0 }.joined(separator: " ")
    }

    private static func unit(_ value: Int, _ name: String) -> String {
        "\(value) \(name)\(value == 1 ? "" : "s")"
    }
}
