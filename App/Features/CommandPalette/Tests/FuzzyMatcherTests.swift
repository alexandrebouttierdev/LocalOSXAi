import Foundation
import Testing
@testable import LocalOSXAi

@Suite("FuzzyMatcher")
struct FuzzyMatcherTests {
    @Test("an empty query matches with score zero")
    func emptyQuery() {
        #expect(FuzzyMatcher.score("", in: "Anything") == 0)
        #expect(FuzzyMatcher.score("   ", in: "Anything") == 0)
    }

    @Test("characters must appear in order")
    func subsequence() {
        #expect(FuzzyMatcher.score("opr", in: "Open Project") != nil)
        #expect(FuzzyMatcher.score("rpo", in: "Open Project") == nil)
        #expect(FuzzyMatcher.score("xyz", in: "Open Project") == nil)
    }

    @Test("matching ignores case, diacritics and spaces in the query")
    func normalization() {
        #expect(FuzzyMatcher.score("OPEN", in: "open project") != nil)
        #expect(FuzzyMatcher.score("resume", in: "Résumé") != nil)
        #expect(FuzzyMatcher.score("new s", in: "New Session") != nil)
    }

    @Test("prefix and word starts rank above scattered matches")
    func ranking() throws {
        let initials = try #require(FuzzyMatcher.score("ns", in: "New Session"))
        let scattered = try #require(FuzzyMatcher.score("ns", in: "Open Changes"))
        #expect(initials > scattered)

        let prefix = try #require(FuzzyMatcher.score("term", in: "Terminal"))
        let inner = try #require(FuzzyMatcher.score("term", in: "Open Determined"))
        #expect(prefix > inner)
    }

    @Test("consecutive characters rank above gapped ones")
    func consecutive() throws {
        // Same length, no word starts: only adjacency differs.
        let tight = try #require(FuzzyMatcher.score("mod", in: "xmodxxx"))
        let loose = try #require(FuzzyMatcher.score("mod", in: "xmxoxdx"))
        #expect(tight > loose)
    }

    @Test("initials match strongly, like editor palettes")
    func initials() throws {
        let initials = try #require(FuzzyMatcher.score("mod", in: "Make Old Directory"))
        let midWord = try #require(FuzzyMatcher.score("mod", in: "Commodore"))
        #expect(initials > midWord)
    }

    @Test("best score picks the strongest candidate")
    func bestScore() {
        #expect(FuzzyMatcher.bestScore("diff", in: ["Show Changes", "diff"]) == FuzzyMatcher.score("diff", in: "diff"))
        #expect(FuzzyMatcher.bestScore("zzz", in: ["a", "b"]) == nil)
    }
}
