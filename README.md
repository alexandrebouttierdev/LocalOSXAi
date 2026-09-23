# LocalOSXAi

A native macOS coding agent for **local models**: Ollama, LM Studio and, later, any
OpenAI-compatible server.

## What is the project?

LocalOSXAi aims to be a controlled, predictable and pleasant development agent for local
models. It is a native SwiftUI app with a Linear-inspired interface: dense but readable,
keyboard-first and restrained. It is built to stay maintainable for years. It is not a
prototype, and it is not meant to be a clone of Cline or OpenCode.

## Features

Status as of **Phase 3 (agent runtime)**:

| Area | Status |
|---|---|
| Native window, sidebar / content / inspector layout | ✅ |
| Linear-like design system (tokens, components, light/dark, Increase Contrast) | ✅ |
| Command palette (⌘K), menu commands and shortcuts | ✅ |
| Project selection (open folder, recent projects) | ✅ (in memory until Phase 5) |
| Sessions (create, resume, auto-title) | ✅ (in memory until Phase 5) |
| Agent with tools: read, list, search files and text, edit and write files | ✅ |
| Approval of file changes (allow once / for the session / deny), stop anytime | ✅ |
| Context management: budget, compaction, `AGENTS.md` loading | ✅ |
| Streaming with reasoning, context meter | ✅ |
| Ollama and LM Studio providers, model discovery, provider settings | ✅ |
| Model selection grouped by provider (inspector, ⌘L) | ✅ |
| Core contracts: `LLMProvider`, `AgentTool`, `ToolRegistry`, schema validation | ✅ |
| Terminal, Git, diff/changes review, command permissions, Files tab | Phase 4 |
| SQLite persistence, history, settings | Phase 5 |
| Polish, animations, accessibility audit, performance | Phase 6 |

The agent works inside the opened project folder only. It reads freely, but every file change
needs your approval. It cannot run commands yet (Phase 4). To work on the UI without any
model server, run with `LOCALOSXAI_SIMULATED=1`. A **Simulated** badge then appears in the
sidebar.

## Architecture

MVVM + feature-first + dependency injection + protocols at boundaries.

```
View → ViewModel → Service / use case → Protocol ← Infrastructure
```

The agent runtime depends only on `LLMProvider`. The UI depends only on `AgentService`.
Concrete implementations are chosen in one place, `App/Application/AppEnvironment.swift`.
Read [docs/architecture.md](docs/architecture.md).

## Requirements

- macOS 15 or later (developed on macOS 26)
- Xcode 26 or later (Swift 6.2 toolchain)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) and [SwiftLint](https://github.com/realm/SwiftLint)
  (`brew install xcodegen swiftlint`)
- [Ollama](https://ollama.com) and/or [LM Studio](https://lmstudio.ai) running locally (configurable in Settings → Providers)

## Development

```bash
make generate   # create LocalOSXAi.xcodeproj from project.yml
make open       # open in Xcode
make build
```

The Xcode project is generated from `project.yml` and is not committed. Run `make generate`
after adding, moving or removing files.

## Testing

```bash
make test     # all tests, no model server needed
make check    # lint + architecture rules + docs check + build + tests: the validation gate
make test-live  # opt-in: checks the providers against your running Ollama / LM Studio
```

Tests use Swift Testing and never contact a real model. `FakeLLMProvider` simulates
streaming, tool calls, malformed calls, errors, timeouts and cancellation. See
[docs/code/testing.md](docs/code/testing.md).

## Project structure

```
App/
├── Application/      entry point, composition root, menu commands
├── Core/             provider-agnostic contracts: AI, tools, context, logging, errors
├── Features/         Workspace, CommandPalette, Projects, Sessions, Agent, Models, Settings
├── Infrastructure/   providers (Ollama, OpenAI-compatible), storage, settings, simulations
├── Shared/           design system, reusable components, formatting
└── Resources/        assets, Info.plist
Tests/                Core/Shared/Infrastructure tests and test doubles
docs/                 architecture, conventions, AI, UI, security, ADRs
scripts/              validation scripts
```

## Supported providers

| Provider | Default endpoint | Status |
|---|---|---|
| Ollama | `http://localhost:11434` (native API) | ✅ |
| LM Studio | `http://localhost:1234` (OpenAI-compatible + `/api/v0`) | ✅ |
| Other OpenAI-compatible servers | configurable | provider ready, settings after Phase 2 |

## Security

The app reads and writes project files and runs commands on behalf of a model, so the model's
output is treated as untrusted input. Tools are confined to the project folder, commands go
through a safe / approval / blocked policy, and secrets live only in the Keychain. The app is
not sandboxed, a deliberate choice explained in
[ADR 0009](docs/decisions/0009-no-app-sandbox.md). See [docs/security/](docs/security/permissions.md).

## Documentation

Start at [docs/README.md](docs/README.md). Development agents must read [AGENTS.md](AGENTS.md)
first.

## Roadmap

1. **Foundation** ✅: app shell, design system, navigation, command palette, projects,
   core protocols, test doubles, docs.
2. **Providers** ✅: Ollama and LM Studio providers, model discovery, streaming chat, provider settings.
3. **Agent runtime** ✅: agent loop, context manager (AGENTS.md loading, budgeting, compaction),
   tool executor with approvals, filesystem tools.
4. **Execution**: terminal, Git service, changes/diff review, command permission policy.
5. **Persistence**: SQLite store with migrations, session history, settings.
6. **Polish**: Markdown rendering, animations, accessibility audit, performance, error recovery.
