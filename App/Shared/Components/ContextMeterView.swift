import SwiftUI

/// Shows context consumption as “38.4K / 100K context” with a thin gauge.
///
/// The gauge turns to warning/danger tones near the limit, and the label
/// states “over budget” in text so the state is not conveyed by color alone.
struct ContextMeterView: View {
    let usage: ContextUsage

    private var tone: StatusTone {
        switch usage.fraction {
        case ..<0.75: .accent
        case ..<0.9: .warning
        default: .danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(TokenCountFormatter.contextSummary(usage))
                    .font(AppTypography.callout.monospacedDigit())
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if usage.isOverBudget {
                    StatusBadge(title: "Over budget", systemImage: "exclamationmark.triangle.fill", tone: .danger)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.selection)
                    Capsule()
                        .fill(tone.color)
                        .frame(width: max(proxy.size.width * usage.fraction, usage.usedTokens > 0 ? 3 : 0))
                }
            }
            .frame(height: 4)
            .appAnimation(AppAnimation.standard, value: usage)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Context")
        .accessibilityValue(TokenCountFormatter.accessibilityDescription(usage))
    }
}
