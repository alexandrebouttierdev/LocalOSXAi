import Foundation

/// A line-based unified diff between two texts.
///
/// Uses the standard library's Myers implementation
/// (`CollectionDifference`) and groups changes into hunks with context, like
/// `git diff`. Pure and value-typed so it can run off the main actor.
struct FileDiff: Hashable, Sendable {
    struct Line: Hashable, Sendable {
        enum Kind: Hashable, Sendable { case context, added, removed }
        let kind: Kind
        let text: String
        let oldNumber: Int?
        let newNumber: Int?
    }

    struct Hunk: Hashable, Sendable {
        let lines: [Line]
        var header: String {
            let old = lines.compactMap(\.oldNumber)
            let new = lines.compactMap(\.newNumber)
            return "@@ -\(old.first ?? 0),\(old.count) +\(new.first ?? 0),\(new.count) @@"
        }
    }

    let hunks: [Hunk]
    let addedLines: Int
    let removedLines: Int

    var isEmpty: Bool { hunks.isEmpty }

    static let contextLines = 3

    init(old: String, new: String, context: Int = FileDiff.contextLines) {
        let oldLines = Self.lines(old)
        let newLines = Self.lines(new)
        let difference = newLines.difference(from: oldLines)

        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }

        // Walk both files in parallel to produce the full sequence of lines.
        var all: [Line] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldLines.count || newIndex < newLines.count {
            if oldIndex < oldLines.count, removed.contains(oldIndex) {
                all.append(Line(kind: .removed, text: oldLines[oldIndex], oldNumber: oldIndex + 1, newNumber: nil))
                oldIndex += 1
            } else if newIndex < newLines.count, inserted.contains(newIndex) {
                all.append(Line(kind: .added, text: newLines[newIndex], oldNumber: nil, newNumber: newIndex + 1))
                newIndex += 1
            } else {
                all.append(Line(kind: .context, text: newIndex < newLines.count ? newLines[newIndex] : oldLines[oldIndex],
                                oldNumber: oldIndex + 1, newNumber: newIndex + 1))
                oldIndex += 1
                newIndex += 1
            }
        }

        hunks = Self.group(all, context: context)
        addedLines = inserted.count
        removedLines = removed.count
    }

    /// Keeps changed lines and `context` lines around them; nearby changes share a hunk.
    private static func group(_ lines: [Line], context: Int) -> [Hunk] {
        let changed = lines.indices.filter { lines[$0].kind != .context }
        guard !changed.isEmpty else { return [] }
        var ranges: [ClosedRange<Int>] = []
        for index in changed {
            let range = max(index - context, 0)...min(index + context, lines.count - 1)
            if let last = ranges.last, range.lowerBound <= last.upperBound + 1 {
                ranges[ranges.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                ranges.append(range)
            }
        }
        return ranges.map { Hunk(lines: Array(lines[$0])) }
    }

    private static func lines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var lines = text.components(separatedBy: "\n")
        if text.hasSuffix("\n") { lines.removeLast() }
        return lines
    }
}
