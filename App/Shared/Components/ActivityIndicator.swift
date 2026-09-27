import SwiftUI

/// A prominent, calm loader for work that has no visible output yet: a
/// pulsing symbol, a title with a light sweeping across it, the elapsed time
/// and, for long waits, a hint.
///
/// The sweep is the interface's only gradient: motion feedback drawn in text
/// colors, never decoration (docs/ui/design-system.md). With Reduce Motion the
/// symbol and the sweep stay still; only the time changes.
struct ActivityIndicator: View {
    let title: String
    let systemImage: String
    /// Start of the wait, or `nil` to hide the elapsed time.
    var since: Date?
    /// A second line for the elapsed seconds, or `nil`.
    var hint: (TimeInterval) -> String? = { _ in nil }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: since ?? .now, by: 1)) { context in
            let elapsed = since.map { max(context.date.timeIntervalSince($0), 0) }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: systemImage)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.accentText)
                        .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                    SweepingText(text: title + "…", font: AppTypography.headline, base: AppColors.textSecondary,
                                 animates: !reduceMotion)
                    if let elapsed {
                        Text(DurationFormatter.string(elapsed))
                            .font(AppTypography.caption.monospacedDigit())
                            .foregroundStyle(AppColors.textTertiary)
                            .contentTransition(.numericText())
                    }
                }
                if let hint = elapsed.flatMap(hint) {
                    Text(hint)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xxs)
        .padding(.vertical, AppSpacing.xs + AppSpacing.xxs)
        .background(AppColors.hover, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: AppBorders.hairline)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
