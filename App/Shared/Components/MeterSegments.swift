import Foundation

/// How full each segment of a segmented meter is, from a fraction.
///
/// Kept apart from the view so the rounding is tested: a used context never
/// shows as empty, and a full one fills every segment.
enum MeterSegments {
    /// One level per segment, each in 0...1: full segments, then the partial
    /// one, then empty ones. Any usage above zero lights at least a sliver.
    static func levels(fraction: Double, count: Int) -> [Double] {
        guard count > 0 else { return [] }
        let filled = min(max(fraction, 0), 1) * Double(count)
        return (0..<count).map { index in
            let level = min(max(filled - Double(index), 0), 1)
            return index == 0 && fraction > 0 ? max(level, minimumVisibleLevel) : level
        }
    }

    /// The first segment is at least this full as soon as anything is used.
    static let minimumVisibleLevel = 0.35
}
