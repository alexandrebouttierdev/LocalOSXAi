# 0031: Sign with a Developer ID and notarize, both optional

**Status:** Accepted

## Context
Releases were signed ad hoc (`codesign --sign -`, [releasing.md](../code/releasing.md)). macOS
treats a downloaded, ad-hoc-signed app as untrusted: current macOS refuses the first launch
outright (“Apple could not confirm…”), with no “Open Anyway” on the dialog itself, so every user
had to go through System Settings › Privacy & Security once, or strip the quarantine attribute
in Terminal, before they could run the app at all.

An Apple Developer account (needed for a Developer ID certificate and for notarizing with
`notarytool`) exists for this project now.

## Decision
- `scripts/build-release.sh` takes `SIGNING_IDENTITY` (default `-`, ad hoc) and, when set to a
  Developer ID, `NOTARY_KEY_PATH`/`NOTARY_KEY_ID`/`NOTARY_ISSUER_ID`: with all three, it submits
  the built disk image to `notarytool`, waits, staples the ticket and verifies it (`stapler
  validate`, `spctl --assess --type install`).
- `.github/workflows/release.yml` reads the certificate and the App Store Connect API key from
  repository secrets (`MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_PASSWORD`,
  `ASC_API_KEY_P8_BASE64`, `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`), imports the certificate into
  a throw-away keychain scoped to the job, reads the Developer ID identity string back from it
  (never hand-entered, so it cannot drift from the certificate), and deletes the keychain and
  key file at the end (`if: always()`) even if the build fails.
- **Both stay optional.** Without those secrets, the workflow signs ad hoc exactly as before:
  nothing breaks for a fork, and nothing in `project.yml` or local `make build`/`make check`
  changed — no contributor needs a paid account to build or test the app.
- The release notes are generated from which path ran, so they stop describing the Gatekeeper
  workaround the moment a notarized release is published.
- An App Store Connect **API key** authenticates `notarytool`, not an Apple ID and
  app-specific password: it is scoped, revocable from App Store Connect without touching the
  Apple ID, and needs no 2FA handling in CI.

## Alternatives
- **Keep ad hoc, document the workaround**: what shipped until now. Free, but every user pays
  the friction on every fresh download.
- **Notarize but not sign with a persistent identity** (e.g. a fresh self-signed cert each
  build): notarization requires a certificate issued by Apple (Developer ID Application), so
  this is not possible.
- **Store the certificate as a GitHub Environment with required reviewers**: more process than
  a one-person project needs today; revisit if the project gains other maintainers with push
  access to `main`.

## Consequences
- A notarized release needs no Gatekeeper workaround; README and the release notes are updated
  once a signed, notarized release is confirmed working.
- The signing certificate and notarization key are long-lived secrets in GitHub; they are never
  committed, never logged (only their base64 blobs are read, and only inside the job), and the
  keychain holding the imported certificate is deleted at the end of every run.
- Notarization adds a few minutes to the release build (Apple's service, `--wait`).
