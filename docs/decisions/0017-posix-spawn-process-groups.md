# 0017: Run commands with posix_spawn in their own process group

**Status:** Accepted

## Context
The agent and the Terminal tab run commands such as `npm test` or `swift build`, which start
child processes. Stopping a command (timeout, Stop button, cancelled run) must stop all of them.
`Foundation.Process` cannot create a process group, and terminating it signals only the direct
child.

## Decision
`PosixCommandRunner` spawns with `posix_spawn`, using `POSIX_SPAWN_SETPGROUP` (a new group led by
the command) and `POSIX_SPAWN_CLOEXEC_DEFAULT` (no leaked descriptors). Termination signals the
whole group with SIGINT, then SIGTERM, then SIGKILL. Output is read on background threads and
exits are awaited with `waitpid`, never on the main actor. Secrets are scrubbed from the
environment. `CommandRunner` is a protocol, so every consumer is tested with a stub, and the
runner itself is tested with real processes.

## Alternatives
- **`Foundation.Process` + `terminate()`**: leaves orphaned children running.
- **`Process` launching `setsid`/`pgrp` wrappers**: macOS has no `setsid` command, and it relies on external tools.
- **A pseudo-terminal (PTY)**: needed for interactive programs, and more complex. It is left
  for a later, interactive terminal.

## Consequences
- Stopping is reliable, and a test verifies that no child process survives cancellation.
- Interactive programs (editors, prompts) cannot be used in the terminal: stdin is `/dev/null`.
- Low-level code (C strings, pipes) is concentrated in one file and documented there.
