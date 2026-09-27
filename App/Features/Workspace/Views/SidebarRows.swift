import SwiftUI

// Rows and marks of the workspace sidebar (`SidebarView`).

/// A row's leading symbol, in its hue or the sidebar's quieter icon tone.
struct SidebarIcon: View {
    let systemImage: String
    var tint: Color = AppColors.textSecondary

    var body: some View {
        Image(systemName: systemImage)
            .font(AppTypography.body)
            .foregroundStyle(tint)
            .frame(width: AppLayout.rowIconWidth)
            .accessibilityHidden(true)
    }
}

/// Linear's collapsible section title: “Today ▾”.
struct SidebarSectionHeader: View {
    let title: String
    let isCollapsed: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: AppSpacing.xs) {
                Text(title)
                Image(systemName: "arrowtriangle.down.fill")
                    .imageScale(.small)
                    .scaleEffect(0.6)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .accessibilityHidden(true)
            }
            .font(AppTypography.callout.weight(.medium))
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: AppLayout.rowHeight - AppSpacing.xs, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appAnimation(AppAnimation.quick, value: isCollapsed)
        .accessibilityLabel(title)
        .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
        .accessibilityAddTraits(.isHeader)
    }
}

/// One session: an icon for what its agent is doing, then its title on one
/// line. The state is also spoken, never color alone.
struct SessionRowLabel: View {
    let session: Session
    let activity: SessionActivity?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Group {
                switch activity {
                case .running:
                    RunningIcon(animates: !reduceMotion)
                        .accessibilityLabel("Running")
                case .awaitingApproval:
                    Image(systemName: "hand.raised.fill")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.warning)
                        .accessibilityLabel("Waiting for your approval")
                case nil:
                    SidebarIcon(systemImage: "bubble.left")
                }
            }
            .frame(width: AppLayout.rowIconWidth)
            if activity == .running {
                // A light runs across the title while the agent works.
                SweepingText(text: session.title, font: AppTypography.body, base: AppColors.textPrimary,
                             animates: !reduceMotion)
            } else {
                Text(session.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .help(details)
        .accessibilityElement(children: .combine)
    }

    /// Shown on hover: the row itself stays on one line.
    private var details: String {
        let updated = session.updatedAt.formatted(.relative(presentation: .named, unitsStyle: .wide))
        guard session.toolCallCount > 0 else { return "Updated \(updated)" }
        let calls = session.toolCallCount == 1 ? "1 tool call" : "\(session.toolCallCount) tool calls"
        return "Updated \(updated) · \(calls)"
    }
}

/// Linear's “in progress” mark: an accent arc turning on a faint ring.
struct RunningIcon: View {
    let animates: Bool
    private static let size: CGFloat = 12
    private static let lineWidth: CGFloat = 2
    /// Seconds per turn.
    private static let period = 0.9

    var body: some View {
        TimelineView(.animation(paused: !animates)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
            ZStack {
                Circle()
                    .stroke(AppColors.accentSubtle, lineWidth: Self.lineWidth)
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(AppColors.accentText, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(animates ? turn * 360 : -90))
            }
            .frame(width: Self.size, height: Self.size)
        }
    }
}

/// A status dot with a soft halo: green when connected, red when not.
struct StatusDot: View {
    let color: Color
    private static let size: CGFloat = 6
    private static let haloOpacity = 0.25

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: Self.size, height: Self.size)
            .background(Circle().fill(color.opacity(Self.haloOpacity)).frame(width: Self.size * 2, height: Self.size * 2))
            .accessibilityHidden(true)
    }
}
