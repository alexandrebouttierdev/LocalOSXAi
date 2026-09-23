import SwiftUI

/// Motion tokens. Animations are short and never block interaction.
enum AppAnimation {
    /// Hover and selection feedback.
    static let quick = Animation.easeOut(duration: 0.12)
    /// Panels appearing, disclosure changes.
    static let standard = Animation.easeInOut(duration: 0.2)
    /// Floating overlays (command palette).
    static let overlay = Animation.spring(duration: 0.22, bounce: 0)
}

extension View {
    /// Applies `animation` unless the user enabled Reduce Motion, in which
    /// case the change happens without animation.
    func appAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(ReduceMotionAnimation(animation: animation, value: value))
    }
}

private struct ReduceMotionAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
