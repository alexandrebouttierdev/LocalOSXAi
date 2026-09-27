import SwiftUI

/// Linear's window layout: a sidebar flat on the window ground, resizable by
/// dragging its edge, next to the detail.
///
/// Used instead of `NavigationSplitView`, whose sidebar macOS 26 draws as a
/// floating glass panel with its own edge and shadow (ADR 0025).
struct SidebarLayout<Sidebar: View, Detail: View>: View {
    let isSidebarVisible: Bool
    /// Persisted by the caller, clamped to `AppLayout`'s sidebar range.
    @Binding var sidebarWidth: Double
    @ViewBuilder var sidebar: Sidebar
    @ViewBuilder var detail: Detail

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .frame(width: AppLayout.clampedSidebarWidth(sidebarWidth))
                    .transition(.move(edge: .leading).combined(with: .opacity))
                SidebarResizeHandle(width: $sidebarWidth)
            }
            detail
        }
        .background(AppColors.background)
        .appAnimation(AppAnimation.standard, value: isSidebarVisible)
    }
}

/// The draggable edge between the sidebar and the detail. Invisible, like
/// Linear's: the inset content panel already marks the boundary.
private struct SidebarResizeHandle: View {
    @Binding var width: Double
    @State private var widthAtDragStart: Double?

    var body: some View {
        Color.clear
            .frame(width: AppSpacing.xs)
            .contentShape(Rectangle())
            .pointerStyle(.frameResize(position: .trailing))
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        let start = widthAtDragStart ?? width
                        widthAtDragStart = start
                        width = Double(AppLayout.clampedSidebarWidth(start + drag.translation.width))
                    }
                    .onEnded { _ in widthAtDragStart = nil }
            )
            .accessibilityHidden(true)
    }
}
