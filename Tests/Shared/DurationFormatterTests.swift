import Foundation
import Testing
@testable import LocalOSXAi

@Suite("DurationFormatter")
struct DurationFormatterTests {
    @Test("seconds under a minute, then minutes, then hours and minutes")
    func string() {
        #expect(DurationFormatter.string(12.44) == "12 s")
        #expect(DurationFormatter.string(12.44, precise: true) == "12.4 s")
        #expect(DurationFormatter.string(59.9) == "59 s")
        #expect(DurationFormatter.string(60) == "1:00 min")
        #expect(DurationFormatter.string(125, precise: true) == "2:05 min")
        #expect(DurationFormatter.string(3_599) == "59:59 min")
        #expect(DurationFormatter.string(3_600) == "1:00 h")
        #expect(DurationFormatter.string(3_900) == "1:05 h")
        #expect(DurationFormatter.string(-3) == "0 s")
    }

    @Test("VoiceOver hears words, not abbreviations")
    func spoken() {
        #expect(DurationFormatter.spoken(1) == "1 second")
        #expect(DurationFormatter.spoken(0) == "0 seconds")
        #expect(DurationFormatter.spoken(125) == "2 minutes 5 seconds")
        #expect(DurationFormatter.spoken(120) == "2 minutes")
        #expect(DurationFormatter.spoken(3_900) == "1 hour 5 minutes")
        #expect(DurationFormatter.spoken(7_200) == "2 hours")
    }
}
