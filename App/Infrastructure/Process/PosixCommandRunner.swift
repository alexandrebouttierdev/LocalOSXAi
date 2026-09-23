import Darwin
import Foundation
import Synchronization

/// Runs commands with `posix_spawn` in their own process group.
///
/// `Foundation.Process` cannot create a process group, so stopping a command
/// like `npm test` would leave its `node` children running. Here the command
/// is the leader of a new group and termination signals the whole group:
/// SIGINT, then SIGTERM, then SIGKILL, each after a grace period
/// (docs/security/command-execution.md).
struct PosixCommandRunner: CommandRunner {
    static let shellPath = "/bin/zsh"
    static let gracePeriod: Duration = .milliseconds(1_500)
    /// Environment variable names that look like secrets are removed.
    static let secretNameFragments = ["KEY", "TOKEN", "SECRET", "PASSWORD", "PASSWD", "CREDENTIAL"]

    func run(_ request: CommandRequest) -> AsyncThrowingStream<CommandEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    try await Self.execute(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Execution

    private static func execute(_ request: CommandRequest,
                                continuation: AsyncThrowingStream<CommandEvent, Error>.Continuation) async throws {
        let start = ContinuousClock.now
        let process = try SpawnedProcess.launch(argv: argv(for: request.invocation), directory: request.workingDirectory,
                                                environment: scrubbedEnvironment())
        let timedOut = Flag()

        let readers = [
            process.read(fd: process.stdout) { continuation.yield(.output($0, .stdout)) },
            process.read(fd: process.stderr) { continuation.yield(.output($0, .stderr)) }
        ]
        let timeoutTask = request.timeout.map { limit in
            Task.detached {
                try await Task.sleep(for: limit)
                timedOut.set()
                await process.terminate()
            }
        }

        let status = await withTaskCancellationHandler {
            await process.waitForExit()
        } onCancel: {
            Task.detached { await process.terminate() }
        }
        timeoutTask?.cancel()
        // Background children (`server &`) can keep the pipes open after the
        // command exits: give remaining output a moment, then end the group.
        let watchdog = Task.detached {
            try await Task.sleep(for: .seconds(2))
            killpg(process.pid, SIGKILL)
        }
        for reader in readers { await reader.value }
        watchdog.cancel()

        if Task.isCancelled { throw CancellationError() }
        continuation.yield(.exited(CommandExit(code: status, duration: ContinuousClock.now - start,
                                               timedOut: timedOut.isSet)))
    }

    private static func argv(for invocation: CommandRequest.Invocation) -> [String] {
        switch invocation {
        case .shell(let command):
            // Login shell so PATH includes Homebrew and version managers, as in the user's terminal.
            [shellPath, "-l", "-c", command]
        case let .executable(path, arguments):
            [path] + arguments
        }
    }

    static func scrubbedEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        environment.filter { name, _ in
            let upper = name.uppercased()
            return !secretNameFragments.contains { upper.contains($0) }
        }
    }
}

/// A thread-safe boolean that can be captured by concurrent closures
/// (a `Mutex` itself is non-copyable and cannot be captured).
private final class Flag: Sendable {
    private let state = Mutex(false)
    var isSet: Bool { state.withLock { $0 } }
    func set() { state.withLock { $0 = true } }
}

/// A process started with `posix_spawn`, its output pipes and its exit status.
///
/// `Sendable` because its only mutable state (`exitStatus`) is behind a Mutex;
/// pid and descriptors are immutable after launch.
private final class SpawnedProcess: Sendable {
    let pid: pid_t
    let stdout: Int32
    let stderr: Int32
    private let exitStatus = Mutex<Int32?>(nil)

    private init(pid: pid_t, stdout: Int32, stderr: Int32) {
        self.pid = pid
        self.stdout = stdout
        self.stderr = stderr
    }

    static func launch(argv: [String], directory: URL, environment: [String: String]) throws -> SpawnedProcess {
        var outPipe: [Int32] = [0, 0]
        var errPipe: [Int32] = [0, 0]
        guard pipe(&outPipe) == 0, pipe(&errPipe) == 0 else { throw TerminalError.launchFailed("cannot create pipes") }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, outPipe[1], 1)
        posix_spawn_file_actions_adddup2(&actions, errPipe[1], 2)
        posix_spawn_file_actions_addchdir_np(&actions, directory.path)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // New process group (so the whole tree can be signalled) and no inherited descriptors.
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setpgroup(&attributes, 0)

        let cArguments = argv.map { strdup($0) } + [nil]
        let cEnvironment = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            cArguments.forEach { free($0) }
            cEnvironment.forEach { free($0) }
        }

        var pid: pid_t = 0
        let result = posix_spawn(&pid, argv[0], &actions, &attributes, cArguments, cEnvironment)
        close(outPipe[1])
        close(errPipe[1])
        guard result == 0 else {
            close(outPipe[0])
            close(errPipe[0])
            throw TerminalError.launchFailed(String(cString: strerror(result)))
        }
        return SpawnedProcess(pid: pid, stdout: outPipe[0], stderr: errPipe[0])
    }

    /// Reads `fd` until end of file on a background thread, decoding UTF-8
    /// without splitting multi-byte characters across chunks.
    func read(fd: Int32, onText: @escaping @Sendable (String) -> Void) -> Task<Void, Never> {
        Task.detached {
            var pending = Data()
            var buffer = [UInt8](repeating: 0, count: 16_384)
            while true {
                let count = Darwin.read(fd, &buffer, buffer.count)
                if count <= 0 { break }
                pending.append(buffer, count: count)
                let complete = UTF8Boundary.completePrefixLength(of: pending)
                if complete > 0 {
                    // Lossy on purpose: invalid bytes in process output become U+FFFD instead of dropping the chunk.
                    // swiftlint:disable:next optional_data_string_conversion
                    onText(String(decoding: pending.prefix(complete), as: UTF8.self))
                    pending.removeFirst(complete)
                }
            }
            // swiftlint:disable:next optional_data_string_conversion
            if !pending.isEmpty { onText(String(decoding: pending, as: UTF8.self)) }
            close(fd)
        }
    }

    /// Waits for the process without blocking a cooperative thread.
    func waitForExit() async -> Int32 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { [self] in
                var status: Int32 = 0
                while waitpid(pid, &status, 0) == -1, errno == EINTR {}
                let code = Self.exitCode(fromWaitStatus: status)
                exitStatus.withLock { $0 = code }
                continuation.resume(returning: code)
            }
        }
    }

    var hasExited: Bool { exitStatus.withLock { $0 != nil } }

    /// Signals the whole group, escalating until it exits.
    func terminate() async {
        for signal in [SIGINT, SIGTERM, SIGKILL] {
            guard !hasExited else { return }
            killpg(pid, signal)
            try? await Task.sleep(for: PosixCommandRunner.gracePeriod)
        }
    }

    /// Decodes a `waitpid` status (the WIFEXITED/WEXITSTATUS macros are not
    /// available in Swift): signalled processes report 128 + signal.
    static func exitCode(fromWaitStatus status: Int32) -> Int32 {
        let signal = status & 0x7F
        return signal == 0 ? (status >> 8) & 0xFF : 128 + signal
    }
}

/// UTF-8 chunk boundaries, so streamed output never shows broken characters.
enum UTF8Boundary {
    /// Length of the longest prefix of `data` that does not end inside a
    /// multi-byte character.
    static func completePrefixLength(of data: Data) -> Int {
        let bytes = [UInt8](data.suffix(4))
        let offset = data.count - bytes.count
        // Walk back over continuation bytes (10xxxxxx) to the last lead byte.
        var index = bytes.count - 1
        while index >= 0, bytes[index] & 0xC0 == 0x80 { index -= 1 }
        guard index >= 0 else { return data.count }
        let lead = bytes[index]
        let expected = lead & 0x80 == 0 ? 1 : lead & 0xE0 == 0xC0 ? 2 : lead & 0xF0 == 0xE0 ? 3 : lead & 0xF8 == 0xF0 ? 4 : 1
        let available = bytes.count - index
        return available >= expected ? data.count : offset + index
    }
}
