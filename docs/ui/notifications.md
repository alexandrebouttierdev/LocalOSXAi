# Notifications and sound

*Implemented.* A run can take minutes on a local model, so the user often switches to another
app, session or tab. When a session needs them again, the app tells them
([ADR 0027](../decisions/0027-notifications.md)).

## When

`AgentViewModel` reports an `AgentAttention` through its `onAttention` callback:

| Moment | Attention | Notification body |
|---|---|---|
| The run answered | `.answered(preview:)` | The start of the answer, on one line, at most 180 characters |
| The run paused at its step limit | `.pausedAtStepLimit` | “The agent paused after its step limit. Send “continue” to resume.” |
| The run failed | `.failed(message:)` | “The run failed: …” |
| A tool call waits for approval | `.approvalNeeded(summary:)` | “Approval needed: …” |

A run the user stopped (⌘.) and a compaction are not reported: the user is already there.

## Notification or sound

`WorkspaceViewModel.notify` decides with `AttentionResponse.response(to:…)`, a pure function:

- The user **sees the session** (`isVisible`: the app is frontmost, the settings screen is
  closed, the Agent tab shows that session) → only the **sound**, if turned on.
- Otherwise → a **notification** (title: the session, subtitle: the project), with the
  notification sound if the sound is on. With notifications off, the sound alone.

`isAppActive` is set by `WorkspaceView` from `NSApplication` activation notifications.

## Settings

Settings › General › Notifications: **Show notifications** and **Play a sound**, both on by
default (`AgentSettings.showsNotifications`, `playsSound`, optional when decoding). They are read
each time a session needs the user (`WorkspaceServices.notificationPreferences`), so a change
applies at once.

## System integration

- `UserNotifying` (Core/Notifications, shared by Workspace and Settings) is the boundary; `SystemUserNotifier`
  (Infrastructure/Notifications) implements it with the User Notifications framework and
  `NSSound` (“Tink”, short and quiet) for the sound alone.
- Permission is asked **at launch** while notifications are on (`prepareNotifications`), and
  when they are turned on in Settings, so the macOS prompt appears while the user is in the
  app. Asked on the first notification instead, the prompt came while the user was elsewhere and
  was easily missed, and nothing was shown until it was answered. Declined or failed
  notifications are only logged.
- Settings › General › Notifications shows the **macOS permission** (Allowed, Not asked yet with
  “Allow Notifications…”, Off in System Settings with “Open System Settings…”) and has **Send
  Test Notification**, which posts one at once to check Focus modes and banner style.
- Notifications of a session share a thread in Notification Center. **Clicking one** activates
  the app and opens the session (`WorkspaceViewModel.openSession`), selecting its project and
  closing the settings screen if needed.
- Simulated mode posts nothing (no notifier), so UI snapshots never trigger a permission prompt.

## Tests

`AttentionResponseTests` (decision and bodies), `AgentViewModelAttentionTests` (what is
reported, and that a stopped run is not), `WorkspaceNotificationTests` (background, visible,
other tab or settings, click opens the session across projects) and `AgentSettingsTests`.
