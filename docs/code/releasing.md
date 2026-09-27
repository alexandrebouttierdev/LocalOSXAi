# Releasing

*Implemented:* `.github/workflows/release.yml` publishes a GitHub release on every push to
`main`. Day-to-day work happens on `dev`; merging `dev` into `main` releases it.

## What a push to `main` does

1. Runs `make check` (lint, architecture rules, docs, build, all tests) on macOS with Xcode 26.
   A red check means no release.
2. Reads the version from `project.yml` (`CFBundleShortVersionString`, via
   `scripts/app-version.sh`) and picks the tag:
   - `v<version>` if that version was never released: a normal release;
   - `v<version>-build.<run>` otherwise: a **pre-release**, so a push never fails.
3. Builds a universal (Apple Silicon and Intel) Release app with `scripts/build-release.sh`,
   sets its build number (`CFBundleVersion`) to the workflow run number, signs it ad hoc and
   packs it in a disk image, `LocalOSXAi-<version>.dmg`: the app next to a link to
   Applications, to drag it there. A disk image rather than a zip: nothing to unpack, and it is
   the usual way Mac apps are installed.
4. Creates the release with the disk image, install steps and notes generated from the merged
   pull requests and commits.

## Publishing a new version

1. Bump `CFBundleShortVersionString` in `project.yml` (and `App/Resources/Info.plist`, which
   XcodeGen rewrites from it). The first release is `0.0.0.1`; versions are dotted numbers,
   compared number by number, so `0.0.0.2` follows it, and `0.0.1` or `0.1` are later still.
2. Merge into `main`. The workflow publishes `v0.0.0.2`.

To build the same disk image locally: `scripts/build-release.sh 1` (writes `dist/`).

## Replacing a release's files

To rebuild the current version without publishing a new one (a packaging fix, say): Actions ›
Release › Run workflow, with **Rebuild the current version and replace its existing release's
files** checked. If `v<version>` exists, its files are replaced by the new disk image, other
files are removed and the install steps are rewritten; the tag and its commit do not move.
Without an existing release, the run publishes it normally.

## Update check

At launch the app asks GitHub for the latest release and, if it is newer than the running
version, shows an **Update** pill at the bottom of the sidebar; **Check for Updates…** does the
same on request ([ADR 0030](../decisions/0030-update-check.md)). Only full releases count:
pre-releases (`-build.N`) are never offered. So a version bump in `project.yml` is what makes
users see an update.

## Website

The landing page in `site/` is published to GitHub Pages by `.github/workflows/pages.yml` when
it changes on `dev` ([site/README.md](../../site/README.md)). Its download buttons point to the
latest release, so a new release needs no change to the site.

## Signing and notarization

`build-release.sh` signs with a Developer ID and notarizes when these repository secrets exist
(Settings › Secrets and variables › Actions), ad hoc and un-notarized otherwise — no other
change needed, and the release notes reflect whichever happened. See
[ADR 0031](../decisions/0031-code-signing-notarization.md).

| Secret | What |
|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | A **Developer ID Application** certificate and its private key, exported from Keychain Access as `.p12` (right-click the identity › Export…, set an export password), then `base64 -i Certificate.p12 \| pbcopy`. |
| `MACOS_CERTIFICATE_PASSWORD` | The export password chosen above. |
| `ASC_API_KEY_P8_BASE64` | An App Store Connect API key: [appstoreconnect.apple.com](https://appstoreconnect.apple.com) › Users and Access › Integrations › Keys, **Generate API Key** with Developer access. Downloads once as `AuthKey_<key ID>.p8`; `base64 -i AuthKey_….p8 \| pbcopy`. |
| `ASC_API_KEY_ID` | The Key ID shown next to it. |
| `ASC_API_ISSUER_ID` | The Issuer ID at the top of that page (shared by every key). |

The certificate needs a Developer ID Application identity from an enrolled Apple Developer
account (Certificates, Identifiers & Profiles › Certificates). The signing identity itself
(`SIGNING_IDENTITY`) is read from the imported certificate at build time, not stored as a secret.

Once the secrets are set, the next push to `main` (or a “replace files” run) signs and
notarizes; the release notes and README stop mentioning the Gatekeeper warning automatically
once a notarized release is published — update them by hand at that point.
