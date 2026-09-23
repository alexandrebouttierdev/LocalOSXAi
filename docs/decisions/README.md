# Architecture Decision Records

An ADR records a decision that had more than one reasonable option, so future contributors
understand *why* the code is the way it is. Write one before changing the global architecture.

## Format

File: `NNNN-short-title.md`, numbered sequentially. Sections:

- **Status**: Proposed · Accepted · Superseded by NNNN
- **Context**: the problem and the forces at play
- **Decision**: what we do
- **Alternatives**: options considered, and why they were not chosen
- **Consequences**: what becomes easier, what becomes harder, and follow-ups

Accepted ADRs are not edited to change their decision. Write a new ADR that supersedes them.

## Index

| # | Decision | Status |
|---|---|---|
| [0001](0001-swiftui.md) | SwiftUI for the whole interface, AppKit only at the edges | Accepted |
| [0002](0002-mvvm.md) | MVVM with `@Observable` ViewModels | Accepted |
| [0003](0003-feature-first.md) | Feature-first organization | Accepted |
| [0004](0004-provider-abstraction.md) | `LLMProvider` abstraction, provider-agnostic agent | Accepted |
| [0005](0005-agent-runtime.md) | Event-stream agent runtime behind `AgentService` | Accepted |
| [0006](0006-persistence.md) | SQLite via GRDB behind repositories (Phase 5) | Accepted |
| [0007](0007-terminal-execution.md) | Parsed-command policy for terminal execution | Accepted |
| [0008](0008-context-management.md) | Conservative context budgeting with explicit instructions | Accepted |
| [0009](0009-no-app-sandbox.md) | No App Sandbox; Hardened Runtime plus application-level boundaries | Accepted |
| [0010](0010-xcodegen-project-generation.md) | Generate the Xcode project with XcodeGen | Accepted |
| [0011](0011-swift-testing.md) | Swift Testing for all tests | Accepted |
| [0012](0012-single-module-with-enforced-rules.md) | Single app module with script-enforced dependency rules | Accepted |
| [0013](0013-direct-chat-before-agent-runtime.md) | Ship a direct streaming chat in Phase 2, before the tool runtime | Accepted |
| [0014](0014-trust-loaded-context-size.md) | Trust the runtime's loaded context size (amends 0008) | Accepted |
