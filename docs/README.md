# Documentation

Every document explains **why** a decision was made, not only what the code does.
Each one marks what is *implemented* and what is *planned* (with its phase).

| Area | Start here | Contents |
|---|---|---|
| Architecture | [architecture.md](architecture.md) | [overview](architecture/overview.md), [features](architecture/feature-architecture.md), [dependency rules](architecture/dependency-rules.md), [concurrency](architecture/concurrency.md) |
| Code | [code/rules.md](code/rules.md) | [naming](code/naming.md), [Swift style](code/swift-style.md), [documentation](code/documentation.md), [testing](code/testing.md) |
| Data | [data/overview.md](data/overview.md) | [models](data/models.md), [persistence](data/persistence.md), [migrations](data/migrations.md) |
| AI | [ai/overview.md](ai/overview.md) | [providers](ai/providers.md), [agent](ai/agent.md), [tools](ai/tools.md), [context](ai/context.md), [streaming](ai/streaming.md), [errors](ai/errors.md), [model capabilities](ai/model-capabilities.md) |
| UI | [ui/design-system.md](ui/design-system.md) | [navigation](ui/navigation.md), [components](ui/components.md), [accessibility](ui/accessibility.md) |
| Security | [security/permissions.md](security/permissions.md) | [command execution](security/command-execution.md) |
| Decisions | [decisions/README.md](decisions/README.md) | Architecture Decision Records |

## Keeping docs true

- Change the docs in the same change as the code they describe.
- If you make a decision with more than one reasonable option, add an ADR.
- If a document describes something planned, say which phase will deliver it.
