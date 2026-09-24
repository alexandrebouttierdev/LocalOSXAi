import SwiftUI

/// The view switcher in the window toolbar: text-only tabs whose selection is
/// a glass capsule that slides (and, on macOS 26, morphs) from one tab to the
/// next, with a pending-count badge on Changes.
struct TabSwitcher: View {
    @Binding var selectedTab: MainTab
    let changesCount: Int
    @Namespace private var namespace

    var body: some View {
        AppGlassContainer(spacing: 0) {
            HStack(spacing: AppSpacing.xxs) {
                ForEach(MainTab.allCases) { tab in
                    TabButton(tab: tab, isSelected: tab == selectedTab, badge: tab == .changes ? changesCount : 0, namespace: namespace) {
                        selectedTab = tab
                    }
                }
            }
            .padding(AppSpacing.xxs + 1)
            .background(AppColors.hover, in: Capsule())
            .overlay(Capsule().strokeBorder(AppColors.hairline, lineWidth: AppBorders.hairline))
        }
        .appAnimation(AppAnimation.overlay, value: selectedTab)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Views")
    }
}

private struct TabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let badge: Int
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                // Text only, like Linear's view switcher: the labels are short
                // and icons would add noise to a four-tab control.
                Text(tab.title)
                if badge > 0 {
                    Text("\(badge)")
                        .font(AppTypography.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xs + 1)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(AppColors.accent, in: Capsule())
                        .accessibilityLabel("\(badge) pending")
                }
            }
                .font(AppTypography.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.textPrimary : (isHovered ? AppColors.textPrimary : AppColors.textSecondary))
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 26)
                .contentShape(Capsule())
                .background {
                    if isSelected {
                        Capsule()
                            .fill(AppColors.selection)
                            .appGlass(in: Capsule())
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                            .appGlassID("selectedTab", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .appAnimation(AppAnimation.quick, value: isHovered)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
