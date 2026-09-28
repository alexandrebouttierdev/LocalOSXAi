import Foundation
import Testing
@testable import LocalOSXAi

@Suite("AppVersion")
struct AppVersionTests {
    @Test("reads versions and release tags", arguments: [
        ("0.0.0.1", [0, 0, 0, 1]),
        ("v0.0.0.1", [0, 0, 0, 1]),
        ("V1.2", [1, 2]),
        (" 2.10.3 ", [2, 10, 3])
    ])
    func parses(text: String, components: [Int]) throws {
        let version = try #require(AppVersion(text))
        #expect(version.components == components)
        #expect(version.suffix == nil)
    }

    @Test("keeps a pre-release tag's suffix apart from its numbers")
    func suffix() throws {
        let version = try #require(AppVersion("v0.0.0.1-build.12"))
        #expect(version.components == [0, 0, 0, 1])
        #expect(version.suffix == "build.12")
    }

    @Test("rejects anything that is not dotted numbers", arguments: [
        "", "v", "—", "latest", "1..2", "1.", ".1", "1.2a", "+1.0", "-1.0", "1.٣", "99999999999999999999999"
    ])
    func rejects(text: String) {
        #expect(AppVersion(text) == nil)
    }

    @Test("compares number by number, missing components counting as zero")
    func comparison() throws {
        func version(_ text: String) throws -> AppVersion { try #require(AppVersion(text)) }
        #expect(try version("0.0.0.2") > version("0.0.0.1"))
        #expect(try version("0.0.1") > version("0.0.0.9"))
        #expect(try version("0.1") > version("0.0.99.99"))
        #expect(try version("0.0.0.10") > version("0.0.0.9"))
        #expect(try version("1.2") == version("1.2.0.0"))
        #expect(try Set([version("1.2"), version("1.2.0")]).count == 1)
        #expect(try !(version("0.0.0.1-build.3") > version("0.0.0.1")))
        #expect(try version("v0.0.0.1").description == "0.0.0.1")
    }
}
