# LocalOSXAi

A native macOS coding agent for **local models**: Ollama, LM Studio and, later, any
OpenAI-compatible server.

## What is the project?

LocalOSXAi aims to be a controlled, predictable and pleasant development agent for local
models. It is a native SwiftUI app with a Linear-inspired interface: dense but readable,
keyboard-first and restrained. It is built to stay maintainable for years. It is not a
prototype, and it is not meant to be a clone of Cline or OpenCode.

## Features

Status as of **Phase 1 (foundation)**:

| Area | Status |
|---|---|
| Native window, sidebar / content / inspector layout | ✅ |
| Linear-like design system (tokens, components, light/dark, Increase Contrast) | ✅ |
| Command palette (⌘K), menu commands and shortcuts | ✅ |
| Project selection (open folder, recent projects) | ✅ (in memory until Phase 5) |
| Sessions (create, resume, auto-title) | ✅ (in memory until Phase 5) |
| Agent conversation UI (streaming, reasoning, tool calls, stop) | ✅ on a **simulated** agent |
| Model selection grouped by provider | ✅ on a **simulated** provider |
| Core contracts: `LLMProvider`, `AgentTool`, `ToolRegistry`, schema validation | ✅ |
| Ollama / LM Studio providers, model discovery, streaming | Phase 2 |
| Agent runtime, context manager, filesystem tools | Phase 3 |
| Terminal, Git, diff/changes review, command permissions | Phase 4 |
| SQLite persistence, history, settings | Phase 5 |
| Polish, animations, accessibility audit, performance | Phase 6 |

While providers and the agent are simulated, the app shows a **Simulated** badge in the
sidebar. No model is called and no file is modified.

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
- For real models (from Phase 2): [Ollama](https://ollama.com) and/or [LM Studio](https://lmstudio.ai)

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
├── Infrastructure/   storage and simulated services (providers from Phase 2)
├── Shared/           design system, reusable components, formatting
└── Resources/        assets, Info.plist
Tests/                Core/Shared/Infrastructure tests and test doubles
docs/                 architecture, conventions, AI, UI, security, ADRs
scripts/              validation scripts
```

## Supported providers

| Provider | Default endpoint | Status |
|---|---|---|
| Ollama | `http://localhost:11434` | Phase 2 |
| LM Studio | `http://localhost:1234/v1` | Phase 2 |
| OpenAI-compatible | configurable | after Phase 2 |

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
2. **Providers**: Ollama and LM Studio providers, model discovery, streaming, provider settings.
3. **Agent runtime**: agent loop, context manager (AGENTS.md loading, budgeting, compaction),
   tool executor, filesystem tools.
4. **Execution**: terminal, Git service, changes/diff review, command permission policy.
5. **Persistence**: SQLite store with migrations, session history, settings.
6. **Polish**: Markdown rendering, animations, accessibility audit, performance, error recovery.
