# 0009: No App Sandbox; Hardened Runtime and application-level boundaries

**Status:** Accepted

## Context
A coding agent must read and write arbitrary project folders and run the developer's
toolchain (git, compilers, package managers). Child processes of a sandboxed app inherit its
sandbox and cannot access most of what those tools need.

## Decision
Ship without the App Sandbox (so no Mac App Store distribution), with the Hardened Runtime,
distributed as a notarized app. Replace sandbox guarantees with explicit application rules:
project-root boundaries for tools, a command permission policy, secrets in the Keychain only,
and privacy-aware logging.

## Alternatives
- **Sandbox + security-scoped bookmarks**: works for file access, but breaks command
  execution. This is the same reason other developer tools are not sandboxed.
- **Sandboxed app + unsandboxed XPC helper**: the helper would hold all the power anyway, at
  the cost of significant complexity.

## Consequences
- Security depends on our own rules being correct, so they are documented and tested
  (docs/security/).
- The Mac App Store is not a distribution channel.
- Local builds are ad-hoc signed (Hardened Runtime is effectively disabled for ad-hoc
  signing). Release builds need a Developer ID and notarization.
