# 0012: Single app module with script-enforced dependency rules

**Status:** Accepted

## Context
The layering rules (views do not touch infrastructure, Core is provider-agnostic, only the
composition root creates implementations) could be enforced by splitting the code into Swift
packages. That adds `public` annotations, build configuration and friction to every change.

## Decision
Keep a single app module for now. Enforce the rules with `scripts/check-architecture.sh`
(run by `make architecture` and `make check`), which greps non-comment code by folder, and
with review. Revisit when Core stabilizes after Phase 3. Extracting `Core` into a package is
the expected first step.

## Alternatives
- **Swift packages per layer or feature now**: compiler-enforced, but premature while the
  contracts are still moving.
- **Rely on review only**: rules erode silently.

## Consequences
- Rules are checked quickly and stay readable. The checks are heuristics, so review is still
  required.
- Moving to packages later will be mostly mechanical because the rules already hold.
