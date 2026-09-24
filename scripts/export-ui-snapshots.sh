#!/usr/bin/env bash
# Exports the screenshots attached by UISnapshotTests into a folder, one PNG
# per screen, named after the screen (e.g. dark-2-answer.png).
set -euo pipefail
result="$1"
output="$2"
mkdir -p "$output"
xcrun xcresulttool export attachments --path "$result" --output-path "$output" > /dev/null
python3 - "$output" <<'PY'
import json, os, sys
folder = sys.argv[1]
manifest = os.path.join(folder, "manifest.json")
for test in json.load(open(manifest)):
    for attachment in test.get("attachments", []):
        name = attachment["suggestedHumanReadableName"].split("_0_")[0] + ".png"
        os.replace(os.path.join(folder, attachment["exportedFileName"]), os.path.join(folder, name))
os.remove(manifest)
PY
ls "$output"
