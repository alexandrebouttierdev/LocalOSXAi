import SwiftUI

/// Context consumption, Linear-style: a progress ring and “2.2K / 32.8K” with
/// the percentage, over a segmented bar.
///
/// Motion (off with Reduce Motion): the segments fill left to right in a
/// wave and empty right to left, the ring and the numbers roll to the new
/// value, and while a run is updating the context, the leading segment
/// breathes. Near the limit the tone turns to warning, then danger, and
/// “Over budget” is written out, so the state never rests on color alone.
struct ContextMeterView: View {
    let usage: ContextUsage
    /// A run is in progress: the usage is about to change.
    var isActive = false

    static let segmentCount = 24
    private static let barHeight: CGFloat = 6
    private static let segmentRadius: CGFloat = 1.5
    private static let ringWidth: CGFloat = 2
    /// Delay between two segments of the wave: the whole bar takes ~0.4 s.
    private static let waveStep = 0.018

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The fraction drawn, set on appear so the first display animates too.
    @State private var shown = 0.0
    @State private var isGrowing = true

    private var tone: Color {
        switch usage.fraction {
        case ..<0.75: AppColors.accent
        case ..<0.9: AppColors.warning
        default: AppColors.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                ring
                HStack(spacing: 0) {
                    Text(TokenCountFormatter.string(for: usage.usedTokens))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText(value: Double(usage.usedTokens)))
                    Text(" / \(TokenCountFormatter.string(for: usage.budgetTokens))")
                        .foregroundStyle(AppColors.textTertiary)
                }
                .font(AppTypography.callout.monospacedDigit())
                Spacer(minLength: AppSpacing.xs)
                if usage.isOverBudget {
                    StatusBadge(title: "Over budget", systemImage: "exclamationmark.triangle.fill", tone: .danger)
                } else {
                    Text(usage.fraction.formatted(.percent.precision(.fractionLength(0))))
                        .font(AppTypography.caption.monospacedDigit())
                        .foregroundStyle(AppColors.textTertiary)
                        .contentTransition(.numericText(value: usage.fraction))
                }
            }
            .animation(reduceMotion ? nil : AppAnimation.standard, value: usage)
            segments
        }
        .onAppear { shown = usage.fraction }
        .onChange(of: usage.fraction) { old, new in
            isGrowing = new >= old
            shown = new
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Context")
        .accessibilityValue(TokenCountFormatter.accessibilityDescription(usage))
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(AppColors.selection, lineWidth: Self.ringWidth)
            Circle()
                .trim(from: 0, to: max(shown, usage.usedTokens > 0 ? 0.04 : 0))
                .stroke(tone, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: AppSpacing.md, height: AppSpacing.md)
        .animation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.15), value: shown)
    }

    private var segments: some View {
        let levels = MeterSegments.levels(fraction: shown, count: Self.segmentCount)
        let leading = levels.lastIndex { $0 > 0 }
        return HStack(spacing: AppSpacing.xxs) {
            ForEach(levels.indices, id: \.self) { index in
                segment(level: levels[index], index: index, isLeading: index == leading)
            }
        }
        .frame(height: Self.barHeight)
    }

    private func segment(level: Double, index: Int, isLeading: Bool) -> some View {
        // The wave runs in the direction of the change.
        let step = isGrowing ? index : Self.segmentCount - 1 - index
        let fill = RoundedRectangle(cornerRadius: Self.segmentRadius, style: .continuous)
        return fill
            .fill(AppColors.selection)
            .overlay(fill.fill(tone).opacity(level))
            .modifier(Breathing(isOn: isLeading && isActive && !reduceMotion))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.28).delay(Double(step) * Self.waveStep), value: level)
            .animation(reduceMotion ? nil : AppAnimation.standard, value: tone)
    }
}

/// Slowly dims and brightens a view while `isOn`.
private struct Breathing: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.phaseAnimator([1.0, 0.4]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.9) }
        } else {
            content
        }
    }
}
