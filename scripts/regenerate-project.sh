#!/usr/bin/env bash
# Regenerates LocalOSXAi.xcodeproj after git changed the working tree, so a
# pull that adds, renames or removes files never leaves Xcode looking for
# files that no longer exist. Called by the hooks in .githooks (`make hooks`).
#
# Never fails: a git command must not break because XcodeGen is missing.
# `--use-cache` skips generation when neither project.yml nor the file list
# changed, so most pulls cost nothing.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 0

# Git clients started from the Dock (Xcode, GitHub Desktop) do not load the
# shell profile, so Homebrew's paths may be missing.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "LocalOSXAi: xcodegen not found, the Xcode project was not regenerated (brew install xcodegen)." >&2
  exit 0
fi

if ! xcodegen generate --quiet --use-cache; then
  echo "LocalOSXAi: xcodegen failed; run 'make generate' to see why." >&2
fi
exit 0
