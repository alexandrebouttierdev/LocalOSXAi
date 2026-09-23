import Foundation

/// One command typed in the integrated terminal and its output.
struct TerminalEntry: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        case running
        case finished(CommandExit)
        case cancelled
        case failed(String)
    }

    /// Consecutive output of one stream, merged so rendering stays cheap.
    struct Chunk: Hashable, Sendable {
        let stream: CommandOutputStream
        var text: String
    }

    /// Output kept per entry. Older output is dropped beyond this, and the
    /// entry says so: a runaway command must not exhaust memory.
    static let maxOutputCharacters = 200_000

    let id: UUID
    let command: String
    let startedAt: Date
    var chunks: [Chunk] = []
    var state: State = .running
    private(set) var droppedCharacters = 0

    init(id: UUID = UUID(), command: String, startedAt: Date) {
        self.id = id
        self.command = command
        self.startedAt = startedAt
    }

    var outputCharacters: Int { chunks.reduce(0) { $0 + $1.text.count } }

    mutating func append(_ text: String, from stream: CommandOutputStream) {
        if chunks.last?.stream == stream {
            chunks[chunks.count - 1].text += text
        } else {
            chunks.append(Chunk(stream: stream, text: text))
        }
        var overflow = outputCharacters - Self.maxOutputCharacters
        while overflow > 0, !chunks.isEmpty {
            if chunks[0].text.count <= overflow {
                overflow -= chunks[0].text.count
                droppedCharacters += chunks[0].text.count
                chunks.removeFirst()
            } else {
                chunks[0].text.removeFirst(overflow)
                droppedCharacters += overflow
                overflow = 0
            }
        }
    }
}
