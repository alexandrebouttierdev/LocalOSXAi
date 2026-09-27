import SwiftUI

/// Text with an accent highlight moving from leading to trailing, once per
/// period: the loader's title and the title of a session at work.
///
/// Motion feedback, the interface's only gradient (docs/ui/design-system.md).
/// Without `animates` (Reduce Motion), plain text in the base color.
struct SweepingText: View {
    static let period: TimeInterval = 1.8
    /// Half the width of the highlight, as a fraction of the text width.
    static let halfWidth = 0.35

    let text: String
    let font: Font
    let base: Color
    let animates: Bool

    var body: some View {
        if animates {
            TimelineView(.animation) { context in
                label.foregroundStyle(sweep(at: context.date))
            }
        } else {
            label.foregroundStyle(base)
        }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// The highlight's center travels past both ends of the text so each
    /// sweep starts and ends with the text at rest. Outside the gradient's
    /// start and end points, the base color extends.
    private func sweep(at date: Date) -> LinearGradient {
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
        let center = -Self.halfWidth + progress * (1 + 2 * Self.halfWidth)
        return LinearGradient(
            colors: [base, AppColors.accentText, base],
            startPoint: UnitPoint(x: center - Self.halfWidth, y: 0.5),
            endPoint: UnitPoint(x: center + Self.halfWidth, y: 0.5)
        )
    }
}
