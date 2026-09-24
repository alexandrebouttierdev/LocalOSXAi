# Command execution

**Status:** implemented in Phase 4. `CommandPolicy` and `ShellCommandParser` are in `Core/Tools`,
`PosixCommandRunner` in `Infrastructure/Process`, `run_command` in `Infrastructure/Tools/Terminal`,
and the Terminal tab in `Features/Terminal`. See [ADR 0007](../decisions/0007-terminal-execution.md)
and [ADR 0017](../decisions/0017-posix-spawn-process-groups.md).

## Classification

`CommandPolicy.decision(for:projectRoot:)` classifies a command line as **allowed**,
**requires approval** or **blocked**.

The command is **parsed, not pattern-matched on raw text**. `ShellCommandParser` applies POSIX
quoting rules (single quotes, double quotes, backslashes) and splits the line into simple
commands on `&&`, `||`, `;`, `|` and `&`, recording output redirections. Each segment is
classified on its own, and **the strictest decision wins**. Leading assignments (`FOO=1 npm test`)
are skipped to find the program.

Anything whose meaning depends on runtime expansion requires approval: `$VAR`, `$(…)`,
backticks, `{a,b}`, subshells and here-documents. Unbalanced quotes also require approval.

| Decision | Examples (from `CommandPolicyTests`) |
|---|---|
| Allowed | `git status`, `git diff --stat`, `git log`, `git branch`, `git stash list`, `ls`, `cat … \| head`, `rg`, `find` (without `-delete`/`-exec`), `npm test`, `npm run test:*`, `swift test`, `swift build`, `make check`, `xcodebuild test`, `cargo test`, `<tool> --version`, `… > /dev/null` |
| Requires approval | `npm install`, `brew install`, `git commit`, `git push`, `git checkout`, bare `git stash`, `git branch -D`, `rm` inside the project, `mv`, `curl`, writing to a file (`> notes.txt`), `find -delete`, any unknown program, expansion or substitution |
| Blocked | `sudo`/`su`/`doas`; recursive `rm`/`chmod`/`chown` on `/`, `~`, `..`, `.`, `*` or an absolute path outside the project; `curl`/`wget` piped into a shell or interpreter; `git push --force` to `main`/`master`; `dd of=/dev/…`; `mkfs`, `diskutil`, `shutdown`, `reboot`, `launchctl`, `csrutil`, `nvram`; fork bombs; an empty command |

The rules are data (program sets in `CommandPolicy`). Making them configurable per project is
planned, not implemented yet.

## Who decides

| Caller | Allowed | Requires approval | Blocked |
|---|---|---|---|
| The agent (`run_command`, via `ToolPermissionPolicy`) | Runs | Approval banner (allow once / for the session / deny) | Refused, and the model is told why |
| The user (Terminal tab) | Runs | Runs: it is the user's own action | Explicit “Run anyway?” confirmation, since the likely cause is a pasted mistake |

## Execution (`PosixCommandRunner`)

- **`posix_spawn`, not `Foundation.Process`**, so the command becomes the leader of a **new
  process group** (`POSIX_SPAWN_SETPGROUP`). Stopping a command therefore stops everything it
  started (`npm` → `node` → workers). `POSIX_SPAWN_CLOEXEC_DEFAULT` prevents any other descriptor
  of the app from leaking into the child.
- **Shell commands** run as `/bin/zsh -l -c <command>`. The login shell gives the same `PATH` as
  the user's terminal (Homebrew, version managers). Git runs **without a shell**
  (`/usr/bin/git --no-optional-locks -C <root> …`), so paths never need quoting.
- **Working directory:** the project root. **stdin:** `/dev/null`.
- **Environment:** inherited, minus every variable whose name contains `KEY`, `TOKEN`, `SECRET`,
  `PASSWORD`, `PASSWD` or `CREDENTIAL`.
- **Output:** stdout and stderr are streamed separately, decoded as UTF-8 without splitting
  multi-byte characters across chunks.
- **Termination** (timeout, Stop, cancellation): `SIGINT` to the group, then `SIGTERM`, then
  `SIGKILL`, 1.5 s apart, stopping as soon as the process exits. If background children keep
  the pipes open after the command exits, the group is killed after 2 s.
- **Exit:** code, duration and a timed-out flag. A process killed by a signal reports 128 + the signal.

| Limit | Value |
|---|---|
| `run_command` timeout | 120 s (the tool's own limit is 130 s, so the command's timeout fires first) |
| Output sent to the model | 16,000 characters, keeping head and tail |
| Output kept per terminal entry | 200,000 characters (the oldest are dropped, with a notice) |
| Git commands | 20 s |

## Git

`GitService` (implemented by `CLIGitService`) reads status (porcelain v2, NUL-separated, so any
file name is safe), diff and log. The agent gets `git_status`, `git_diff` and `git_log`, which
are read-only. Git operations that change the repository (commit, checkout, stash, push) go
through `run_command`, so they are classified and need approval. Dedicated, confirmed Git
actions in the UI are a later step.

## Tests

`CommandPolicyTests` (tables for every decision, compound commands, quoting), `ShellCommandParserTests`,
`PosixCommandRunnerTests` (streams, exit codes, working directory, timeout, cancellation that
**verifies child processes are gone**, environment scrubbing, UTF-8, direct executables),
`RunCommandToolTests` (policy through the executor), `TerminalViewModelTests`, `CLIGitServiceTests`
(real temporary repositories).
