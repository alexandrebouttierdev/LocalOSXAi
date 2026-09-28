# 0030: Check GitHub Releases at launch; download in the browser

**Status:** Accepted

## Context
Releases are published on GitHub by `release.yml` on every push to `main`
([releasing.md](../code/releasing.md)). Users who downloaded the app had no way to know a newer
version exists. The app promises that code and prompts stay on the Mac, so any network call it
makes on its own must be small, explained and optional.

## Decision
- At launch, `UpdatesViewModel` asks `ReleaseChecking` for the latest release, in the
  background: the workspace never waits for it. `GitHubReleaseChecker` calls
  `GET https://api.github.com/repos/alexandrebouttierdev/LocalOSXAi/releases/latest`,
  anonymously. The only thing sent is `User-Agent: LocalOSXAi/<version>`, which GitHub requires.
- That endpoint skips drafts and **pre-releases**, so the `-build.N` pre-releases of repeated
  pushes are never offered.
- Versions are dotted numbers of any length (the first release is `0.0.0.1`), compared number
  by number; missing components count as zero (`AppVersion`).
- A newer version shows as an **Update** pill at the bottom of the sidebar; nothing pops up.
  The update window shows the versions, the release notes and **Download**, which opens the
  release page in the browser. “Later” hides the pill until the next launch.
- A check at launch fails silently (logged, category `updates`). **Check for Updates…** (app
  menu, palette, Settings › General › Updates) always shows its result, failures included.
- Settings › General › Updates › “Check for updates at launch” turns the launch check off
  (`AgentSettings.checksForUpdates`, on by default). Simulated mode has no checker.
- The response is untrusted: a tag that is not a version is an error, notes are cut to 6,000
  characters, and the page opened is always under
  `https://github.com/alexandrebouttierdev/LocalOSXAi/releases/`, otherwise the latest release
  page.

## Alternatives
- **Sparkle**: downloads, verifies and installs updates in place. It needs an appcast, EdDSA
  signing keys in CI and, to be smooth, a Developer ID signature and notarization, which the
  project does not have yet. Worth revisiting once releases are notarized.
- **Install from the app** (download the disk image and replace the bundle): the app is ad-hoc signed
  and quarantined; replacing a running app ourselves is fragile and a security surface.
- **No check**: users stay on old versions without knowing it.
- **A periodic check** while the app runs: more network traffic for little gain; the app is
  usually relaunched often enough.

## Consequences
- One anonymous HTTPS request per launch to `api.github.com`, which the user can turn off. The
  README and Settings say what is sent.
- GitHub allows 60 anonymous requests per hour per network address; a rate-limited check says
  so and the next launch tries again.
- Updating stays manual: download, then replace the app in Applications.
