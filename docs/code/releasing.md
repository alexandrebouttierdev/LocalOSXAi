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

## Signing

The app is signed **ad hoc**, not with a Developer ID, and not notarized: macOS asks users to
confirm the first launch (right-click › Open, or remove the quarantine attribute). The release
notes say so. Notarizing needs an Apple Developer account; when one exists, add the certificate
and an App Store Connect API key as repository secrets and sign with `codesign` and
`notarytool` in `build-release.sh` (planned).
