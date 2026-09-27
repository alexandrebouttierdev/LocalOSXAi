# Contributing to LocalOSXAi

Thank you for helping. LocalOSXAi aims to be a **controlled, predictable** coding agent for
local models, built to stay maintainable for years. Contributions are welcome when they keep it
that way: small, tested, documented.

By contributing, you agree that your work is released under the [MIT License](LICENSE) and that
you follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

- **Bugs**: open an issue with the bug template: steps, what you expected, the model and
  provider, macOS and app versions.
- **Features**: open an issue first to agree on the approach, especially for anything touching
  the agent runtime, tools, permissions or storage.
- **Security problems**: never in a public issue. See [SECURITY.md](SECURITY.md).

## Set up

Requirements: macOS 15 or later, Xcode 26 (Swift 6.2 toolchain),
`brew install xcodegen swiftlint`.

```bash
git clone https://github.com/alexandrebouttierdev/LocalOSXAi.git
cd LocalOSXAi
make hooks      # regenerate the Xcode project after every pull or branch switch
make generate   # create LocalOSXAi.xcodeproj from project.yml
make open
```

The `.xcodeproj` is generated and not committed: edit `project.yml`, never the project file.
To work on the interface without a model server, run with `LOCALOSXAI_SIMULATED=1`.

## How changes are made

The rules for humans and AI agents are the same, and live in [AGENTS.md](AGENTS.md). In short:

1. Read the docs of the area you change ([docs/README.md](docs/README.md)).
2. Respect the architecture: `View → ViewModel → Service → Protocol ← Infrastructure`,
   feature-first folders, infrastructure created only in `AppEnvironment`
   ([dependency rules](docs/architecture/dependency-rules.md)).
3. Write or update tests with the change (Swift Testing, never a real model server:
   use `FakeLLMProvider` and the other doubles in `Tests/Support`).
4. Update the documentation, and add an ADR in `docs/decisions/` for any decision that had
   several reasonable options.
5. Run the gate:

   ```bash
   make check   # lint, architecture rules, docs links, build and all tests
   ```

   Warnings are errors. Never delete or weaken a test to make it pass.

## Code style

[docs/code/rules.md](docs/code/rules.md) is authoritative: Swift 6 strict concurrency, no force
unwraps, no singletons, `Logger` instead of `print`, typed errors at boundaries, design tokens
instead of literal colors and spacing, comments that explain *why*.

## Pull requests

- One topic per pull request; keep unrelated changes out.
- Explain what changed and why, and how you tested it (the template asks).
- Screenshots or a short video for any visible change, in light and dark mode.
- CI must be green: it runs `make check` on macOS.

## Releases

Work lands on `dev`. Merging into `main` publishes a GitHub release automatically; bump the
version in `project.yml` first for a new version number ([docs/code/releasing.md](docs/code/releasing.md)).

## Security-sensitive areas

Changes to tools, the project boundary, the command policy, approvals or secret storage get a
closer review. The model is untrusted input: validate every tool call, never run anything
silently, keep secrets in the Keychain only
([docs/security/permissions.md](docs/security/permissions.md)).
