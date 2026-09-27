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
   zips it to `LocalOSXAi-<version>.zip`.
4. Creates the release with the zip, install steps and notes generated from the merged pull
   requests and commits.

## Publishing a new version

1. Bump `CFBundleShortVersionString` in `project.yml` (and `App/Resources/Info.plist`, which
   XcodeGen rewrites from it), following [semantic versioning](https://semver.org):
   `0.1.0` → `0.2.0` for features, `0.1.1` for fixes.
2. Merge into `main`. The workflow publishes `v0.2.0`.

To build the same archive locally: `scripts/build-release.sh 1` (writes `dist/`).

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
