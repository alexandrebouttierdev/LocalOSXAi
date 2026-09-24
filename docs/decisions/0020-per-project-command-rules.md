# 0020: Per-project command rules only move commands between “allowed” and “ask”

**Status:** Accepted

## Context
The built-in `CommandPolicy` asks before any command that changes things (`npm install`,
`git commit`…). In a project where the user runs the same commands all day, approving each one
is noise; in a sensitive project, the user may want to approve even read-only commands. Both
needs are per project.

## Decision
- `CommandRules` is stored with the project: a **mode** (`standard`, or `askForEverything`) and
  a list of **allowed prefixes** compared word by word (`npm install` allows
  `npm install lodash`, not `npm ci` or `npm installer`).
- Rules apply per segment: a compound command runs without asking only if every segment is
  allowed. Shell expansion, substitution and redirections still ask.
- **Rules never unblock a command.** Blocked commands (privilege escalation, recursive deletion
  outside the project, downloads piped into a shell…) stay blocked whatever the rules say.
- The approval card offers “Always Allow “npm install” in This Project” (program plus
  subcommand, only for single plain commands). It applies at once in the session and is saved
  with the project.
- Rules apply to the agent only. The Terminal tab is the user's own action and keeps its
  behavior (see [command-execution.md](../security/command-execution.md)).

## Alternatives
- **Regular expressions or globs**: more power, much easier to get dangerously wrong. Prefixes
  cover the real cases.
- **A global allowlist**: simpler, but a rule trusted in one project would leak into all.
- **Letting rules override blocks**: rejected; the blocked list is the safety net.

## Consequences
- The policy stays data plus a small, tested decision function. Tests cover prefix matching,
  compound commands, dynamic syntax, the ask-for-everything mode and that blocks survive rules.
