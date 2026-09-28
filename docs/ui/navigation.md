# Navigation

## Layout

```
┌─ Sidebar ─────────┬─ Main content ──────────────────────────┬─ Inspector ─────┐
│ ● ● ●             │ ✦ project › session               [▥] │ Model           │
│ ▣ project ⌄  🔍 ✎ │─────────────────────────────────────────│ Context         │
│ ▤ Files           │ transcript / view content               │ Git             │
│ ± Changes       2 │                                         │                 │
│ ▹ Terminal        │ composer                                │                 │
│ Today ▾           │                                         │                 │
│ ◌ Fix the flag    │                                         │                 │
│ ⚙ Settings  🦙    │                                         │                 │
└───────────────────┴─────────────────────────────────────────┴─────────────────┘
```

- `SidebarLayout` (sidebar + detail). The inspector is a **properties column inside the content
  panel**, behind a hairline, like Linear's issue properties (`InspectorView`, 300 pt, toggled from
  the panel header or the menu): label/value rows for the model (model, context, temperature,
  reasoning, abilities), the context (usage, instruction files, CLAUDE.md switch, and the
  “Compact session” button, [ADR 0026](../decisions/0026-compact-session.md)) and Git
  (branch, changes, last commit), every changeable value a menu or switch on its row. The sidebar
  sits flat on the window ground, like Linear's, instead of `NavigationSplitView`'s floating
  glass panel on macOS 26 ([ADR 0025](../decisions/0025-flat-sidebar.md)). Drag its edge to
  resize it (200–320 pt, remembered); the View menu hides it, and the panel header then offers
  a button to show it again.
- **No title bar** (`.windowStyle(.hiddenTitleBar)`, like Linear): the traffic lights float over
  the sidebar's top, the window drags by its background, the sidebar's top strip and the panel
  header.
- The sidebar follows Linear's: the **project switcher** row (“▣ project ⌄”, a menu with every
  project, Open Project…, Project Settings…, Reveal in Finder and Remove) with search (⌘K) and
  new session (✎, ⌘N) icons on its right; the project's **views** as icon rows — Files, Changes
  (with its pending count) and Terminal, which replace the old toolbar tabs; then its sessions in
  **collapsible date sections** (“Today ▾”, Yesterday, Previous 7 days, Previous 30 days, Older —
  `SessionGroup`). A session row starts with an icon for its agent: a speech bubble when idle, a
  spinner while it runs, a raised hand while it waits for approval (`SessionActivity`); hovering
  shows when it was updated and its tool calls. Selecting a session shows the Agent view.
- Sidebar rows (`SidebarRow`) have a neutral selection, never the system accent. ↑/↓ move
  through the sessions once the list has focus (clicking a row gives it focus).
- Minimum window size 900×560. Column widths come from `AppLayout`.
- The content panel carries its own **header row**, like a Linear issue: the view's icon,
  “project › session” (`WorkspaceViewModel.windowTitle/windowSubtitle`) and the inspector toggle,
  with a hairline below.
- Views: **Agent** (a session, ⌘1), **Files** (⌘P focuses its search), **Changes** and
  **Terminal**. Each project keeps its own Files, Changes, Terminal and Git state (`ProjectPanels`).
- **Settings are a screen of the main window**, not a separate window
  ([ADR 0024](../decisions/0024-settings-screen.md)). ⌘, (menu, palette or the sidebar's Settings
  button) covers the workspace with `SettingsScreen`: a “‹ Back to app” row (brightens on hover
  and shows its Esc key) and the sections (General, System Prompt, Providers) on the left, the selected section
  on the inset panel. Esc or “Back to app” returns at once to the workspace as it was left;
  going to a tab, a new session or a file search returns too. The workspace stays alive
  underneath (hidden, disabled, without the keyboard focus): rebuilding it on return made “Back
  to app” slow on long conversations.

## State ownership

All navigation state lives in `WorkspaceViewModel`: selected project, session, tab, sidebar
and inspector visibility, palette presentation, the folder importer, and whether the settings
screen is shown with which section (`isSettingsPresented`, `settingsSection`). Views bind to it and
never hold navigation state themselves, which makes navigation testable (`WorkspaceViewModelTests`).

Selection rules:

- Selecting a project resumes its most recently updated session.
- Creating a session selects it and shows the Agent tab.
- Each session's `AgentViewModel` is cached, so a run keeps going when the user switches away.

## Single window

The app uses one `Window`, not a `WindowGroup`. Several windows could drive the same session
concurrently and split its state. Multi-window support is a future decision that needs a
per-session ownership model first.

## Commands and shortcuts

Commands are declared once in `WorkspaceCommand` (title, icon, shortcut, section, keywords)
and used by both the menu bar (`AppCommands`) and the palette. Menus and palette therefore
never disagree.

| Shortcut | Command |
|---|---|
| ⌘K | Command palette |
| ⌘O | Open Project… |
| ⌘N | New Session |
| ⌘P | Search Files… |
| ⌘L | Change Model… |
| — | Compact Session (palette, Go menu, inspector button) |
| — | Check for Updates… (app menu, palette, Settings › General › Updates) |
| ⌘1 – ⌘4 | Agent / Files / Changes / Terminal |
| ⌃⌘S | Toggle sidebar |
| ⌥⌘I | Toggle inspector |
| ⌘, | Settings screen (General, Providers); Esc or “Back to app” returns |
| ↩ / ⌥↩ or ⇧↩ | Send / new line in the composer |
| ⌘. | Stop the running agent or compaction |
| ⌃C / ↑↓ | Stop the running command / browse history (Terminal) |

## Command palette

- Independent of the main view: `CommandPaletteViewModel` filters and ranks `PaletteItem`s,
  and returns the activated item. The owner (Workspace) maps ids to behavior.
- Ranking: `FuzzyMatcher` (subsequence, bonuses for prefix, word starts and consecutive
  characters; case- and diacritic-insensitive).
- An empty query shows grouped sections. Typing shows a flat ranked list.
- Disabled commands stay visible with their reason (“Open a project first”) and cannot run.
- Nested pages: “Change Model…” replaces the list with models grouped by provider without
  closing the palette.
- Keyboard: ↑/↓ (wrapping), ↩ to activate, ⎋ to close. A click on the scrim closes it.
