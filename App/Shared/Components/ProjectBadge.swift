import SwiftUI

/// A small rounded tile with a project's initial, in a hue derived from its
/// name, so projects are recognizable at a glance in lists and breadcrumbs.
struct ProjectBadge: View {
    let name: String
    var size: CGFloat = 18

    /// Deterministic across launches (unlike `hashValue`), so a project keeps its color.
    nonisolated static func paletteIndex(for name: String) -> Int {
        let sum = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return sum % AppColors.projectPalette.count
    }

    var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "?")
            .font(.system(size: size * 0.58, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(AppColors.projectPalette[Self.paletteIndex(for: name)],
                        in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}
