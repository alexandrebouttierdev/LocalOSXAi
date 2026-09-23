# 0008: Conservative context budgeting with explicit instructions

**Status:** Accepted (Phase 3 for ContextManager; estimation and display implemented)

## Context
Local models have small and uncertain context windows. Providers advertise theoretical
maxima, and runtimes may silently truncate (Ollama's `num_ctx`). Several instruction-file
conventions exist (AGENTS.md, CLAUDE.md, .cursor/rules).

## Decision
- Effective context = `min(configured ?? 8K, advertised)`, always sent to the runtime.
- Tokens are estimated with a conservative heuristic (about 4 chars/token plus overhead per
  message), recalibrated from reported usage.
- The prompt is built by priority: system → instructions → current task → recent tool results
  → git → files → history. Compaction truncates tool output, then summarizes old turns, then
  fails clearly.
- AGENTS.md is the primary instruction source. Other conventions are opt-in per project and
  labelled.

## Alternatives
- **Trust advertised context**: produces silently truncated prompts on local runtimes.
- **Ship model-specific tokenizers**: exact counts, but large, model-dependent, and often
  unavailable for local models.
- **Load every instruction convention automatically**: unpredictable merged rules.

## Consequences
- Users with large-context models must raise the configured size once per model.
- Estimates can be off by 10–20%. The reserved output margin absorbs this.
