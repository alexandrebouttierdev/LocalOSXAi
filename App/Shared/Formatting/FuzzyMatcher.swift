import Foundation

/// Scores how well a query matches a candidate string.
///
/// The query characters must appear in order in the candidate (subsequence
/// match, case- and diacritic-insensitive). Matches are rewarded for starting
/// the candidate, starting words and being consecutive, which ranks “np”
/// → “New Project” above “Open Changes”. This mirrors the behavior users
/// expect from editor palettes while staying small and predictable.
enum FuzzyMatcher {
    private static let baseScore = 1
    private static let consecutiveBonus = 5
    private static let wordStartBonus = 8
    private static let prefixBonus = 12
    private static let gapPenalty = 1

    /// Returns `nil` when the query does not match; higher is better.
    /// An empty query matches everything with score 0.
    static func score(_ query: String, in candidate: String) -> Int? {
        let needle = Array(normalize(query).filter { !$0.isWhitespace })
        guard !needle.isEmpty else { return 0 }
        let haystack = Array(normalize(candidate))

        var score = 0
        var needleIndex = 0
        var previousMatch: Int?

        for (index, character) in haystack.enumerated() where needleIndex < needle.count {
            guard character == needle[needleIndex] else { continue }
            score += baseScore
            if index == 0 { score += prefixBonus }
            if isWordStart(haystack, at: index) { score += wordStartBonus }
            if let previousMatch {
                score += previousMatch == index - 1 ? consecutiveBonus : -gapPenalty * min(index - previousMatch - 1, 5)
            }
            previousMatch = index
            needleIndex += 1
        }
        return needleIndex == needle.count ? score : nil
    }

    /// Best score of the query against any of `candidates`.
    static func bestScore(_ query: String, in candidates: [String]) -> Int? {
        candidates.compactMap { score(query, in: $0) }.max()
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func isWordStart(_ characters: [Character], at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = characters[index - 1]
        return previous == " " || previous == "-" || previous == "_" || previous == "/" || previous == "."
    }
}
