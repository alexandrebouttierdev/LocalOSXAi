import SwiftUI

/// The agent's mark in the transcript. Animates while the agent is working;
/// the animation stops under Reduce Motion (symbol effects honor it).
struct AgentAvatar: View {
    var isWorking = false
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating, isActive: isWorking)
            .frame(width: size, height: size)
            .background(AppColors.accent, in: Circle())
            .accessibilityHidden(true)
    }
}
