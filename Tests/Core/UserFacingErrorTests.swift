import Foundation
import Testing
@testable import LocalOSXAi

@Suite("UserFacingError")
struct UserFacingErrorTests {
    private struct OpaqueError: Error {}

    @Test("uses LocalizedError descriptions and recovery suggestions")
    func localizedError() {
        let error = UserFacingError(ProviderError.unreachable(endpoint: "http://localhost:11434"),
                                    title: "Provider unavailable", category: .provider)
        #expect(error.title == "Provider unavailable")
        #expect(error.message.contains("http://localhost:11434"))
        #expect(error.recoverySuggestion != nil)
    }

    @Test("never exposes internal details of unknown errors")
    func opaqueError() {
        let error = UserFacingError(OpaqueError(), title: "Failed", category: .ui)
        #expect(error.message == "Something went wrong. Details were written to the system log.")
        #expect(error.recoverySuggestion == nil)
    }
}
