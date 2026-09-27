# Navigation

## Layout

```
┌─ Sidebar ─────────┬─ Main content ──────────────────────────┬─ Inspector ─────┐
│ New session   ⌘N  │ Session · Project  Agent Files …  [▥] │ Model           │
│ Search        ⌘K  │─────────────────────────────────────────│ Context         │
│ ▣ project      ⌄  │ transcript / tab content                │ Git             │
│ Today             │                                         │                 │
│  Fix the flag   ◌ │ composer                                │                 │
│ Yesterday         │                                         │                 │
│ ⚙ Settings  🦙    │                                         │                 │
└───────────────────┴─────────────────────────────────────────┴─────────────────┘
```

- `SidebarLayout` (sidebar + detail) plus the `.inspector` modifier (right panel). The sidebar
  sits flat on the window ground, like Linear's, instead of `NavigationSplitView`'s floating
  glass panel on macOS 26 ([ADR 0025](../decisions/0025-flat-sidebar.md)). Drag its edge to
  resize it (200–320 pt, remembered); the toolbar's sidebar button or the menu hides it.
- The sidebar follows Claude Code's: **New session** (⌘N), Search (⌘K), the **project switcher**
  (a menu with every project, Open Project…, Project Settings…, Reveal in Finder and Remove), then
  the project's sessions as one-line rows **grouped by date** (Today, Yesterday, Previous 7 days,
  Previous 30 days, Older — `SessionGroup`). A row shows a spinner while its agent runs and a
  raised hand while it waits for approval (`SessionActivity`), so work in another session is not
  forgotten; hovering shows when it was updated and its tool calls.
- Sidebar rows (`SidebarRow`) have a neutral selection, never the system accent. ↑/↓ move
  through the sessions once the list has focus (clicking a row gives it focus).
- Minimum window size 900×560. Column widths come from `AppLayout`.
- The window toolbar is the only header: title and subtitle (session and project), the tabs in
  the center, the inspector toggle on the right (`WorkspaceViewModel.windowTitle/windowSubtitle`).
- Main content tabs: **Agent**, **Files** (⌘P focuses its search), **Changes** (with a count badge) and **Terminal**. Each project keeps its own Files, Changes, Terminal and Git state (`ProjectPanels`).
  Tabs that are not yet implemented show a placeholder that names their phase.
- **Settings are a screen of the main window**, not a separate window
  ([ADR 0024](../decisions/0024-settings-screen.md)). ⌘, (menu, palette or the sidebar's Settings
  button) replaces the workspace with `SettingsScreen`: “Back to app” and the sections (General,
  Providers) on the left, the selected section on the inset panel. Esc or “Back to app” returns
  to the workspace as it was left; going to a tab, a new session or a file search returns too.

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
| ⌘1 – ⌘4 | Agent / Files / Changes / Terminal |
| ⌃⌘S | Toggle sidebar |
| ⌥⌘I | Toggle inspector |
| ⌘, | Settings screen (General, Providers); Esc or “Back to app” returns |
| ↩ / ⌥↩ | Send / new line in the composer |
| ⌘. | Stop the running agent |
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
