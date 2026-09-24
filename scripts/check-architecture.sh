#!/usr/bin/env bash
# Enforces dependency rules that the compiler cannot check inside a single
# module. Rules and rationale: docs/architecture/dependency-rules.md.
# Exits non-zero and lists every violation found.
set -euo pipefail

cd "$(dirname "$0")/.."
status=0

# Prints code matches of $2 (extended regex) in Swift files whose path matches
# $1 (extended regex), excluding tests and comment lines, and records a failure
# with message $3. Comments are skipped because documentation may legitimately
# name providers or infrastructure types.
check() {
  local path_regex="$1" regex="$2" message="$3"
  local matches
  matches=$(find -E App -type f -regex "$path_regex" -not -path '*/Tests/*' -print0 \
    | xargs -0 grep -nE "$regex" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true)
  if [[ -n "$matches" ]]; then
    echo "✘ $message"
    echo "$matches" | sed 's/^/    /'
    status=1
  fi
}

# 1. Views never reach infrastructure, providers, processes, files or storage.
check '.*/Views/[^/]+\.swift' 'URLSession|Process\(|FileManager|sqlite|SQLite|Repository\(|InMemory[A-Za-z]*Repository|Simulated[A-Za-z]+\(|LLMProvider|\.stream\(request' \
  'Views must go through a ViewModel (no networking, processes, files, storage or providers).'

# 2. ViewModels, Services and Models are UI-framework free, so they are testable without SwiftUI.
check '.*/ViewModels/[^/]+\.swift' '^import SwiftUI' 'ViewModels must not import SwiftUI.'
check '.*/Services/[^/]+\.swift' '^import SwiftUI' 'Services must not import SwiftUI.'
check '.*/Models/[^/]+\.swift' '^import SwiftUI' 'Models must not import SwiftUI.'

# 3. Only the composition root creates infrastructure implementations.
check 'App/Features/.*\.swift' 'InMemory[A-Za-z]*Repository|Simulated[A-Za-z]+(Service|Provider)' \
  'Features must not reference infrastructure types; inject protocols from App/Application/AppEnvironment.swift.'
check 'App/Core/.*\.swift' 'InMemory[A-Za-z]*Repository|Simulated[A-Za-z]+(Service|Provider)|ViewModel' \
  'Core must not depend on infrastructure or features.'

# 3b. SQL stays in the persistence infrastructure (docs/data/persistence.md).
check 'App/(Features|Core|Shared|Application)/.*\.swift' '^import GRDB|DatabaseWriter|DatabaseQueue|DatabasePool' \
  'GRDB and SQL belong in App/Infrastructure/Persistence only.'

# 4. The agent-facing core stays provider-agnostic.
check 'App/Core/.*\.swift' '[Oo]llama|LMStudio|LM Studio|OpenAI' \
  'Core AI and tool contracts must not mention specific providers.'

# 5. Logging goes through os.Logger, never print.
check 'App/.*\.swift' '(^|[^A-Za-z])print\(' 'Use Logger(category:) instead of print().'

# 6. TODO/FIXME in comments must carry a reason or reference: TODO(reason).
#    Checked separately because the rules above deliberately skip comments.
todos=$(find App -type f -name '*.swift' -not -path '*/Tests/*' -print0 \
  | xargs -0 grep -nE '//.*\b(TODO|FIXME)\b([^(]|$)' 2>/dev/null || true)
if [[ -n "$todos" ]]; then
  echo "✘ TODO/FIXME must be written as TODO(reason or link)."
  echo "$todos" | sed 's/^/    /'
  status=1
fi

if [[ $status -eq 0 ]]; then
  echo "✔ Architecture rules satisfied."
fi
exit $status
