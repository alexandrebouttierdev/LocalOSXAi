import Foundation

/// Classifies shell commands proposed by a model: run, ask, or refuse.
///
/// Each simple command of a line (`a && b | c`) is classified on its own and
/// the strictest decision wins. Unknown programs and anything the parser
/// cannot reason about require approval: the policy errs toward asking.
/// Rationale and tables: docs/security/command-execution.md, ADR 0007.
struct CommandPolicy: Sendable {
    enum Decision: Hashable, Sendable, Comparable {
        case allowed
        case requiresApproval(reason: String)
        case blocked(reason: String)

        private var rank: Int {
            switch self {
            case .allowed: 0
            case .requiresApproval: 1
            case .blocked: 2
            }
        }

        static func < (lhs: Decision, rhs: Decision) -> Bool { lhs.rank < rhs.rank }
    }

    /// Read-only or local programs that are safe to run without asking.
    static let readOnlyPrograms: Set<String> = [
        "ls", "cat", "head", "tail", "wc", "pwd", "echo", "printf", "which", "grep", "egrep", "rg", "tree",
        "file", "stat", "du", "df", "date", "whoami", "uname", "sw_vers", "diff", "sort", "uniq", "cut", "tr",
        "basename", "dirname", "realpath", "true", "false", "test", "jq", "less", "column", "nl", "md5", "shasum"
    ]
    static let readOnlyGitSubcommands: Set<String> = [
        "status", "diff", "log", "show", "rev-parse", "blame", "ls-files", "describe", "shortlog", "grep", "reflog"
    ]
    /// `program subcommand` pairs that run tests or builds inside the project.
    static let buildAndTestCommands: Set<String> = [
        "npm test", "npm t", "yarn test", "pnpm test", "bun test", "swift test", "swift build", "make test",
        "make check", "make build", "make lint", "cargo test", "cargo build", "cargo check", "cargo clippy",
        "go test", "go build", "go vet", "pytest", "xcodebuild test", "xcodebuild build", "swiftlint lint", "gradle test"
    ]
    static let privilegePrograms: Set<String> = ["sudo", "su", "doas"]
    static let destructiveSystemPrograms: Set<String> = [
        "mkfs", "shutdown", "reboot", "halt", "launchctl", "diskutil", "csrutil", "nvram", "fdisk"
    ]
    static let shells: Set<String> = ["sh", "bash", "zsh", "fish", "python", "python3", "perl", "ruby", "node"]

    func decision(for command: String, projectRoot: URL) -> Decision {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .blocked(reason: "The command is empty.") }
        if trimmed.contains(":(){") || trimmed.contains(":() {") {
            return .blocked(reason: "This looks like a fork bomb.")
        }
        guard let parsed = ShellCommandParser.parse(trimmed) else {
            return .requiresApproval(reason: "The command could not be parsed.")
        }

        var decision = parsed.hasDynamicSyntax
            ? Decision.requiresApproval(reason: "The command uses shell expansion or substitution.")
            : .allowed
        var previousProgram: String?
        for segment in parsed.segments {
            let words = Self.dropAssignments(segment.words)
            let program = words.first.map { ($0 as NSString).lastPathComponent } ?? ""
            decision = max(decision, classify(program: program, arguments: Array(words.dropFirst()), projectRoot: projectRoot))
            if segment.isPiped, Self.shells.contains(program), let previous = previousProgram, ["curl", "wget"].contains(previous) {
                decision = max(decision, Decision.blocked(reason: "Piping a download into a shell runs unreviewed code."))
            }
            for target in segment.redirections where target != "/dev/null" {
                decision = max(decision, Decision.requiresApproval(reason: "The command writes to \(target)."))
            }
            previousProgram = program
        }
        return decision
    }

    private func classify(program: String, arguments: [String], projectRoot: URL) -> Decision {
        if Self.privilegePrograms.contains(program) {
            return .blocked(reason: "Commands with elevated privileges are never run by the agent.")
        }
        if Self.destructiveSystemPrograms.contains(where: { program == $0 || program.hasPrefix($0 + ".") }) {
            return .blocked(reason: "\(program) can damage the system.")
        }
        if program == "dd", arguments.contains(where: { $0.hasPrefix("of=/dev/") }) {
            return .blocked(reason: "Writing to a device can destroy data.")
        }
        if ["rm", "chmod", "chown"].contains(program), let blocked = recursiveOutsideProject(program, arguments, projectRoot) {
            return blocked
        }
        if program == "git" { return classifyGit(arguments) }
        if Self.readOnlyPrograms.contains(program) { return .allowed }
        if program == "find", !arguments.contains(where: { ["-delete", "-exec", "-execdir", "-ok"].contains($0) }) { return .allowed }
        if let first = arguments.first {
            let pair = "\(program) \(first)"
            if Self.buildAndTestCommands.contains(pair) || (program == "npm" && first == "run" && arguments.count > 1
                && ["test", "lint", "build", "typecheck", "check"].contains(where: { arguments[1].hasPrefix($0) })) {
                return .allowed
            }
            if arguments.count == 1, ["--version", "-v", "-V", "--help", "-h", "version"].contains(first) { return .allowed }
        }
        if Self.buildAndTestCommands.contains(program) { return .allowed }
        return .requiresApproval(reason: program == "rm" ? "This deletes files." : "“\(program)” is not a known read-only or test command.")
    }

    private func classifyGit(_ arguments: [String]) -> Decision {
        let subcommand = arguments.first { !$0.hasPrefix("-") } ?? ""
        let options = arguments.drop { $0 != subcommand }.dropFirst()
        if Self.readOnlyGitSubcommands.contains(subcommand) { return .allowed }
        // Listing branches, tags or remotes is read-only; any other argument changes something.
        if ["branch", "tag", "remote"].contains(subcommand),
           options.allSatisfy({ ["-v", "-vv", "-a", "-r", "-l", "--list", "--show-current"].contains($0) }) {
            return .allowed
        }
        // A bare `git stash` stashes changes: only listing and showing are read-only.
        if subcommand == "stash", let action = options.first, ["list", "show"].contains(action) {
            return .allowed
        }
        if subcommand == "push" {
            let isForce = options.contains { ["--force", "-f", "--force-with-lease"].contains($0) || $0.hasPrefix("+") }
            let targetsProtected = options.contains { ["main", "master"].contains($0) || $0.hasSuffix(":main") || $0.hasSuffix(":master") }
            if isForce, targetsProtected {
                return .blocked(reason: "Force-pushing to a protected branch can destroy shared history.")
            }
        }
        if ["push", "pull", "fetch", "clone"].contains(subcommand) {
            return .requiresApproval(reason: "This contacts a remote repository.")
        }
        return .requiresApproval(reason: "This changes the repository (git \(subcommand)).")
    }

    /// Recursive `rm`/`chmod`/`chown` on the root, home, a wildcard at the top, or outside the project.
    private func recursiveOutsideProject(_ program: String, _ arguments: [String], _ root: URL) -> Decision? {
        let flags = arguments.filter { $0.hasPrefix("-") }
        let isRecursive = flags.contains { $0 == "--recursive" || (!$0.hasPrefix("--") && ($0.contains("r") || $0.contains("R"))) }
        guard isRecursive else { return nil }
        let targets = arguments.filter { !$0.hasPrefix("-") }.dropFirst(program == "rm" ? 0 : 1)
        for target in targets {
            if ["/", "/*", "~", "~/", "*", ".", "..", "../"].contains(target) || target.hasPrefix("~") || target.hasPrefix("../") {
                return .blocked(reason: "Recursive \(program) on “\(target)” reaches outside the project or everything in it.")
            }
            if target.hasPrefix("/"), !ProjectBoundary.contains(URL(fileURLWithPath: target).standardizedFileURL, root: root) {
                return .blocked(reason: "Recursive \(program) on “\(target)” is outside the project.")
            }
        }
        return nil
    }

    /// `FOO=1 npm test` runs `npm`: leading assignments are not the program.
    private static func dropAssignments(_ words: [String]) -> [String] {
        Array(words.drop { word in
            guard let equals = word.firstIndex(of: "="), equals != word.startIndex else { return false }
            return word[..<equals].allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
        })
    }
}
