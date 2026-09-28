# Security Policy

LocalOSXAi lets a language model read and write files and run commands on your Mac. The
model's output is treated as untrusted input, and security reports are taken seriously.

## Supported versions

The project is young: only the latest commit of the default branch (`dev`) and the latest release
receive fixes.

## Reporting a vulnerability

**Do not open a public issue.** Report privately through
[GitHub's private vulnerability reporting](https://github.com/alexandrebouttierdev/LocalOSXAi/security/advisories/new)
with:

- what an attacker (or a malicious model output, file or repository) can achieve;
- steps to reproduce, with the model, provider and app version;
- any idea of a fix.

You will get an answer within a week. Once fixed, the advisory is published with credit to you,
unless you prefer otherwise.

## In scope

- A tool reaching outside the project folder (symlinks, `..`, path tricks).
- A command running without approval when it should need one, or a blocked command running.
- A file change applied without the user's approval.
- Secrets (API keys) leaving the Keychain: logs, SQLite, `UserDefaults`, crash reports.
- Prompt injection from project files or tool output that leads to any of the above.

## Out of scope

- What a model says: wrong or unsafe advice is a model problem, not an app vulnerability, as
  long as every action still goes through the permission policy.
- Commands the user explicitly approved.
- The app is not sandboxed, by design ([ADR 0009](docs/decisions/0009-no-app-sandbox.md)).

The security model is described in [docs/security/](docs/security/permissions.md).
