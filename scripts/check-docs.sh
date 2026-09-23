#!/usr/bin/env bash
# Documentation check: every relative Markdown link and every `docs/...` path
# cited in source comments must point to an existing file, so docs and code
# cannot silently drift apart. Also verifies the mandatory documents exist.
set -euo pipefail

cd "$(dirname "$0")/.."
status=0

required=(
  AGENTS.md README.md docs/README.md docs/architecture.md
  docs/architecture/{overview,feature-architecture,dependency-rules,concurrency}.md
  docs/code/{rules,naming,swift-style,documentation,testing}.md
  docs/data/{overview,models,persistence,migrations}.md
  docs/ai/{overview,providers,agent,tools,context,streaming,errors,model-capabilities}.md
  docs/ui/{design-system,navigation,components,accessibility}.md
  docs/security/{permissions,command-execution}.md
  docs/decisions/README.md
)
for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "✘ Missing required document: $file"; status=1; }
done

# Relative links in Markdown: [text](path) excluding URLs and pure anchors.
while IFS= read -r markdown; do
  dir=$(dirname "$markdown")
  while IFS= read -r target; do
    path="${target%%#*}"
    [[ -z "$path" ]] && continue
    if [[ ! -e "$dir/$path" ]]; then
      echo "✘ Broken link in $markdown → $target"
      status=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$markdown" | sed -E 's/^\]\((.*)\)$/\1/' | grep -vE '^(https?:|mailto:|#)' || true)
done < <(find . -name '*.md' -not -path './.build/*' -not -path './*.xcodeproj/*')

# docs/... references cited in Swift source.
while IFS= read -r reference; do
  file="${reference%%:*}"
  path="${reference#*:}"
  if [[ ! -e "$path" ]]; then
    echo "✘ $file cites missing document $path"
    status=1
  fi
done < <(grep -roE 'docs/[A-Za-z0-9_./-]+\.md' App Tests --include='*.swift' | sort -u)

if [[ $status -eq 0 ]]; then
  echo "✔ Documentation links and references are valid."
fi
exit $status
