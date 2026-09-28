#!/usr/bin/env bash
# Prints the app's marketing version (CFBundleShortVersionString) from
# project.yml, the single place where it is set.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(sed -nE 's/^[[:space:]]*CFBundleShortVersionString:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/p' project.yml | head -1)
[[ -n "$version" ]] || { echo "✘ CFBundleShortVersionString not found in project.yml" >&2; exit 1; }
echo "$version"
