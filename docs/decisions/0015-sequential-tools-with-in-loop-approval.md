# 0015: Sequential tool execution with in-loop approval

**Status:** Accepted

## Context
Models may request several tool calls at once. Some calls (file writes, later commands) need
the user's consent. The loop must stay predictable: the user should understand what happened,
in which order, and be able to stop it at any point.

## Decision
- Tool calls run **sequentially**, in the order the model requested them.
- When the policy requires approval, the runtime **suspends** on `ToolApprover.decide` until the
  user answers in the approval banner. Allow once, allow this tool for the session, or deny.
- A denial is a normal tool result (`denied`) telling the model not to retry. Stopping the run
  answers a pending approval with “deny”.
- Invalid calls are returned to the model. Three consecutive iterations of only-invalid calls
  stop the run.

## Alternatives
- **Parallel tool execution**: faster for independent reads, but approvals and file changes
  would interleave unpredictably. Reads could be parallelized later without changing the
  approval model.
- **Approve before the run (plan mode)**: useful for large changes, but a local model's plan is
  not a reliable description of its actions. It may be added on top later.
- **Auto-approve writes with undo**: depends on the Phase 4 change tracking. It may become an
  opt-in once revert exists.

## Consequences
- The run's order in the transcript is exactly the execution order.
- A multi-call iteration with a slow tool delays the following calls. This is acceptable at local-model speeds.
- The approval UI must always be reachable: it sits above the composer and has keyboard shortcuts.
