# 0027: Notify only when the user is not looking; the sound follows its own switch

**Status:** Accepted

## Context
Runs on local models are slow. Users switch away and come back too late, or keep checking.
They asked for a notification when the agent answers, and for a sound, on by default.

## Decision
- **Four moments**: an answer, a pause at the step limit, a failure, and an approval request
  (the run is blocked until the user answers). Not a run the user stopped, not a compaction.
- **A notification only when the session is not visible**: the app is in the background, or
  another session, tab or the settings screen is shown. A visible session gets the sound only.
- **Two independent switches**, both on: notifications and sound. The sound also plays for a
  visible session, so the user can look away inside the app without missing the end.
- **Permission on first use**, not at launch.
- **Clicking opens the session**, whichever project it belongs to.
- The decision is a pure function (`AttentionResponse`) and the system calls sit behind
  `UserNotifying`, so the rules are tested without the User Notifications framework.

## Alternatives
- **Notify only when the app is in the background**: misses a session finishing while the user
  reads another one or the Files tab.
- **Always notify**: banners over the conversation the user is reading are noise.
- **A notification for every assistant message**: a run produces several (one per step);
  only the end, or a blocked run, needs the user.
- **Ask for permission at launch**: the prompt comes before the user knows why.

## Consequences
- Users who decline the permission still get the sound.
- A session of another project is titled as when its agent was opened, if it was renamed since.
