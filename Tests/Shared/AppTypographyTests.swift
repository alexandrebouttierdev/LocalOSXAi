import AppKit
import Testing
@testable import LocalOSXAi

@Suite("AppTypography")
struct AppTypographyTests {
    @Test("Inter is bundled and registered, so text does not silently fall back to the system font")
    func interIsAvailable() {
        #expect(Bundle.main.url(forResource: "InterVariable", withExtension: "ttf") != nil)
        #expect(NSFont(name: AppTypography.family, size: 13) != nil)
    }
}
