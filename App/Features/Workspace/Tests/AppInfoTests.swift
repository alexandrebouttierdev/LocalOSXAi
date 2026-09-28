import Foundation
import Testing
@testable import LocalOSXAi

@Suite("AppInfo")
struct AppInfoTests {
    @Test("version and build come from the Info.plist")
    func versions() {
        let info = AppInfo(infoDictionary: ["CFBundleDisplayName": "LocalOSXAi", "CFBundleShortVersionString": "0.1.0",
                                            "CFBundleVersion": "7"])
        #expect(info.name == "LocalOSXAi")
        #expect(info.shortVersion == "v0.1.0")
        #expect(info.fullVersion == "Version 0.1.0 (7)")
    }

    @Test("missing values never crash the About window")
    func missing() {
        let info = AppInfo(infoDictionary: [:])
        #expect(info.name == "LocalOSXAi")
        #expect(info.fullVersion == "Version — (—)")
    }

    @Test("the links point to the project, the author's site, its issues and license")
    func links() {
        #expect(AppInfo.repository.absoluteString == "https://github.com/alexandrebouttierdev/LocalOSXAi")
        #expect(AppInfo.website.absoluteString == "https://www.alexandrebouttier.fr")
        #expect(AppInfo.issues.absoluteString == "https://github.com/alexandrebouttierdev/LocalOSXAi/issues")
        #expect(AppInfo.licenseURL.absoluteString.hasSuffix("/LICENSE"))
    }
}
