import Foundation
import Observation

/// The integrated terminal of one project.
///
/// Commands typed here are the user's own actions: they run without the
/// approval the agent needs. Commands the policy would block still ask for
/// an explicit confirmation, because the likely cause is a pasted mistake
/// (docs/security/command-execution.md).
@MainActor
@Observable
final class TerminalViewModel {
    struct Confirmation: Identifiable, Hashable {
        let id = UUID()
        let command: String
        let reason: String
    }

    let projectRoot: URL
    private(set) var entries: [TerminalEntry] = []
    private(set) var history: [String] = []
    private(set) var pendingConfirmation: Confirmation?
    var input = ""

    private let runner: any CommandRunner
    private let policy: CommandPolicy
    private let now: @Sendable () -> Date
    private var runTask: Task<Void, Never>?
    private var historyCursor: Int?

    init(projectRoot: URL, runner: any CommandRunner, policy: CommandPolicy = CommandPolicy(),
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.projectRoot = projectRoot
        self.runner = runner
        self.policy = policy
        self.now = now
    }

    var isRunning: Bool { runTask != nil }

    /// Runs the input, or asks for confirmation when the policy would block it.
    func submit() {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, !isRunning else { return }
        if case .blocked(let reason) = policy.decision(for: command, projectRoot: projectRoot) {
            pendingConfirmation = Confirmation(command: command, reason: reason)
            return
        }
        start(command)
    }

    func confirmPending() {
        guard let confirmation = pendingConfirmation else { return }
        pendingConfirmation = nil
        start(confirmation.command)
    }

    func dismissPending() {
        pendingConfirmation = nil
    }

    /// Interrupts the running command (and everything it started).
    func stop() {
        runTask?.cancel()
    }

    func waitUntilIdle() async {
        await runTask?.value
    }

    /// Removes finished entries.
    func clear() {
        entries.removeAll { $0.state != .running }
    }

    // MARK: History

    func previousCommand() {
        guard !history.isEmpty else { return }
        let cursor = max((historyCursor ?? history.count) - 1, 0)
        historyCursor = cursor
        input = history[cursor]
    }

    func nextCommand() {
        guard let cursor = historyCursor else { return }
        if cursor + 1 < history.count {
            historyCursor = cursor + 1
            input = history[cursor + 1]
        } else {
            historyCursor = nil
            input = ""
        }
    }

    // MARK: Execution

    private func start(_ command: String) {
        input = ""
        historyCursor = nil
        if history.last != command { history.append(command) }
        let entry = TerminalEntry(command: command, startedAt: now())
        entries.append(entry)
        let stream = runner.run(.shell(command, in: projectRoot))
        runTask = Task { [weak self] in
            await self?.consume(stream, entryID: entry.id)
        }
    }

    private func consume(_ stream: AsyncThrowingStream<CommandEvent, Error>, entryID: UUID) async {
        do {
            for try await event in stream {
                update(entryID) { entry in
                    switch event {
                    case let .output(text, source): entry.append(text, from: source)
                    case .exited(let exit): entry.state = .finished(exit)
                    }
                }
            }
            if Task.isCancelled { update(entryID) { $0.state = .cancelled } }
        } catch is CancellationError {
            update(entryID) { $0.state = .cancelled }
        } catch {
            update(entryID) { $0.state = .failed(error.localizedDescription) }
        }
        runTask = nil
    }

    private func update(_ id: UUID, _ change: (inout TerminalEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        change(&entries[index])
    }
}
