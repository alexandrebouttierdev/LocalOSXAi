import Foundation
import Testing
@testable import LocalOSXAi

@Suite("MeterSegments")
struct MeterSegmentsTests {
    @Test("segments fill in order, with one partial segment")
    func levels() {
        #expect(MeterSegments.levels(fraction: 0.5, count: 4) == [1, 1, 0, 0])
        #expect(MeterSegments.levels(fraction: 0.625, count: 4) == [1, 1, 0.5, 0])
        #expect(MeterSegments.levels(fraction: 1, count: 3) == [1, 1, 1])
    }

    @Test("empty stays empty, but any usage lights the first segment")
    func edges() {
        #expect(MeterSegments.levels(fraction: 0, count: 3) == [0, 0, 0])
        #expect(MeterSegments.levels(fraction: 0.001, count: 3).first == MeterSegments.minimumVisibleLevel)
        #expect(MeterSegments.levels(fraction: 2, count: 2) == [1, 1])
        #expect(MeterSegments.levels(fraction: 0.5, count: 0).isEmpty)
    }
}
