#!/usr/bin/env bash
# Creates a small Git project for UI snapshots (make ui-snapshots): a few
# files, one commit and one uncommitted change, so every tab has content.
set -euo pipefail
root="$1"
mkdir -p "$root/Sources"
cat > "$root/README.md" <<'MD'
# Demo
A small command-line tool used for LocalOSXAi screenshots.
MD
cat > "$root/AGENTS.md" <<'MD'
# Rules
Write tests for every change.
MD
cat > "$root/Sources/ExportCommand.swift" <<'SWIFT'
struct ExportCommand {
    var output: String

    func run() throws {
        let archive = try Archive.build()
        try archive.write(to: output)
    }
}
SWIFT
git -C "$root" init -q
git -C "$root" add -A
git -C "$root" -c user.name=Demo -c user.email=demo@example.com commit -q -m "Initial commit"
printf '\n// TODO(demo): add a --dry-run flag\n' >> "$root/Sources/ExportCommand.swift"
