import SwiftUI

/// A model provider's logo, drawn as a template image so it takes the
/// surrounding text color, or a generic server symbol for providers without
/// one (custom OpenAI-compatible servers).
struct ProviderLogo: View {
    /// Image asset name from `ProviderDescriptor.logo`.
    let asset: String?
    var size: CGFloat = 14

    var body: some View {
        Group {
            if let asset {
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "server.rack")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.medium)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
