# Command execution

**Status:** Phase 4. This is the design the terminal and `run_command` implementation must follow.
See also [ADR 0007](../decisions/0007-terminal-execution.md).

## Classification

`CommandPolicy` classifies a command line into **allowed**, **requires approval** or **blocked**.

The command is **parsed, not pattern-matched on raw text**. It is tokenized with shell quoting
rules, and every segment of a compound command (`&&`, `||`, `;`, `|`) is classified. The
strictest segment decides the result. Anything the parser cannot understand confidently
(substitutions `$(…)`/backticks, `eval`, redirection to paths outside the project, here-docs)
requires approval.

| Default decision | Examples |
|---|---|
| Allowed (read-only / test) | `git status`, `git diff`, `git log`, `ls`, `cat`, `rg`, `npm test`, `swift test`, `make test`, `xcodebuild test` |
| Requires approval | `npm install`, `pip install`, `brew install`, `git commit`, `git checkout`, `git stash`, `git push`, `git pull`, `rm` of files inside the project, any unknown command |
| Blocked | `rm -rf /`, `rm -rf ~`, recursive deletion outside the project, `sudo`, `curl … \| sh`, `chmod -R` / `chown -R` outside the project, `mkfs`, `dd of=/dev/…`, `git push --force` to protected branches, fork bombs |

Rules are data: an ordered list of `(matcher, decision, reason)` that users can extend per
project (Phase 5). The reason is shown to the user and returned to the model.

## Execution

- `Process` with `/bin/zsh -lc` **only after** classification. The classified tokens are what
  runs, so a string that parses differently in the shell is not possible.
- Working directory: the project root.
- Environment: inherited minus secret-looking variables (see [permissions.md](permissions.md)).
- stdout/stderr streamed separately as `AsyncStream`s to the terminal UI and captured (capped,
  e.g. 64 KB, keeping head and tail) for the model.
- Timeout (default 120 s), after which it is terminated: `SIGINT`, then `SIGTERM`, then `SIGKILL`
  after grace periods. The whole process group is signalled so child processes stop too.
- Cancellation from the UI or agent follows the same termination sequence.
- The result records the exit code, duration, a truncation flag and the policy decision.

## Integrated terminal

The Terminal tab (Phase 4) is a *command runner* with history, working directory, streaming,
interrupt and exit codes. Commands typed by the user are the user's own actions and run
without approval. Destructive patterns from the blocked list still ask for an explicit
confirmation, because the most likely cause is a pasted mistake.

## Git

`GitService` (Phase 4) wraps the `git` CLI (status, diff, log, branch, then commit, checkout,
stash). Destructive or remote operations (checkout with local changes, stash drop, reset,
push) require confirmation regardless of who initiates them.

## Required tests

Classification tables for each decision, compound commands, quoting edge cases, unparsable
input, successful and failing commands, timeout, cancellation, output truncation, and
environment scrubbing.
