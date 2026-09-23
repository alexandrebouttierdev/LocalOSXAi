# AGENTS.md — Rules for every development agent

Read this file completely before changing anything in this repository. It is
short on purpose; each rule links to the document that explains it.

## 1. What this project is

A native macOS coding agent that runs **local models** (Ollama, LM Studio, any
OpenAI-compatible server). Swift 6, SwiftUI, MVVM, feature-first. The goal is a
*controlled, predictable* agent, not a clone of Cline or OpenCode.
Overview: [README.md](README.md) · Docs index: [docs/README.md](docs/README.md).

## 2. Mandatory workflow for any change

1. Read this file.
2. Read the docs relevant to the change (at least the matching folder in `docs/`).
3. Understand the existing architecture of the features you touch.
4. Identify every feature concerned; prefer changing one feature at a time.
5. Define models and protocols first, if needed.
6. Write or update tests **before or with** the implementation.
7. Implement.
8. Build: `make build`.
9. Run tests: `make test`.
10. Fix every failure and warning. Never delete or weaken a test to make it pass.
11. Update documentation (and add an ADR for any decision with several reasonable options).
12. Review your own diff: no dead code, no debug leftovers, no unrelated changes.

A feature is **not done** because it compiles. It is done when `make check`
passes and the docs describe it.

## 3. Validation commands

```bash
make generate      # regenerate LocalOSXAi.xcodeproj from project.yml (after adding/moving files)
make build         # build the app (warnings are errors)
make test          # unit + integration tests (Swift Testing)
make lint          # SwiftLint, strict
make architecture  # dependency-rule checks (scripts/check-architecture.sh)
make docs          # required docs exist, links and docs/ references resolve
make test-live     # opt-in: provider tests against the local Ollama / LM Studio
make check         # everything above — the gate before calling work finished
```

The `.xcodeproj` is generated and git-ignored. Never edit it by hand; edit
`project.yml`.

## 4. Architecture (non-negotiable)

- Layout: `App/{Application,Core,Features,Infrastructure,Shared,Resources}`.
  See [docs/architecture/overview.md](docs/architecture/overview.md).
- Features are self-contained: `Features/<Name>/{Models,Views,ViewModels,Services,Components,Tests}`.
  No global `Services/` folder. See [feature-architecture.md](docs/architecture/feature-architecture.md).
- Dependency direction: **View → ViewModel → Service/use case → Protocol ← Infrastructure**.
  See [dependency-rules.md](docs/architecture/dependency-rules.md).
- Views never call providers, run processes, touch files or storage, or hold business logic.
- ViewModels are `@MainActor @Observable`, never import SwiftUI, never know provider details.
- Only `App/Application/AppEnvironment.swift` instantiates infrastructure types.
- The agent runtime depends on `LLMProvider`, never on a concrete provider. `Core/` must not
  mention Ollama, LM Studio or OpenAI in code.
- The UI depends on `AgentService`, so it can run on `SimulatedAgentService` or a test stub.
- Do not over-architect: an abstraction must solve a present problem. Priority:
  clarity > correctness > testability > maintainability > performance > abstraction.

## 5. Code conventions

[docs/code/rules.md](docs/code/rules.md) is authoritative. Highlights:

- Swift 6 language mode, strict concurrency, no `@unchecked Sendable` without a documented reason.
- No force unwraps, no singletons, no `print` (use `Logger(category:)`).
- Typed errors at boundaries (`ProviderError`, `ToolError`, `ProjectError`…); convert to
  `UserFacingError` in ViewModels.
- `TODO(reason)` only — never a bare TODO.
- Document *why* (invariants, concurrency, security, non-obvious behavior), not *what*.
- Design tokens only (`AppColors`, `AppSpacing`, `AppTypography`, `AppRadius`…); no literal
  colors or magic spacing in views.

## 6. Tests

- Swift Testing (`import Testing`). Feature tests live in `Features/<Name>/Tests/`;
  Core/Shared/Infrastructure tests and test doubles live in `Tests/`.
- Never depend on a running Ollama/LM Studio: use `FakeLLMProvider` / `MockLLMProvider`
  / `StubAgentService` from `Tests/Support/`.
- Every ViewModel, service, tool and provider gets tests, including failure, cancellation
  and timeout paths. See [docs/code/testing.md](docs/code/testing.md).

## 7. Security

- The model is untrusted input. Validate every tool call; never execute commands silently.
- Tools must stay inside the project root (symlink-resolved).
- Commands go through the permission policy: safe / requires approval / blocked.
- Secrets go in the Keychain only — never in SQLite, `UserDefaults`, logs or source.
- See [docs/security/permissions.md](docs/security/permissions.md) and
  [command-execution.md](docs/security/command-execution.md).

## 8. UI

Linear-inspired, native macOS, restrained. No gradients, big cards, big colored buttons or
"AI startup" styling. Every state is conveyed by text or icon, not color alone. Every control
is reachable by keyboard and labelled for VoiceOver. See [docs/ui/](docs/ui/design-system.md).

## 9. When in doubt

Do not change the global architecture without an ADR in `docs/decisions/`. If a feature is
left partially implemented, say so explicitly in the UI (placeholder with phase) and in your
report.
