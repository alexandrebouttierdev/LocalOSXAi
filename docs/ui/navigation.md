# Navigation

## Layout

```
┌─ Sidebar ─────────┬─ Main content ──────────────────────────┬─ Inspector ─────┐
│ ⌘K Search         │ Project › Session      Agent Files …    │ Model           │
│ Projects      +   │─────────────────────────────────────────│ Context         │
│ Sessions      +   │ transcript / tab content                │ Tools           │
│ Recent            │                                         │ Git             │
│                   │ composer                                │                 │
│ ⚙ Settings  [Sim] │                                         │                 │
└───────────────────┴─────────────────────────────────────────┴─────────────────┘
```

- `NavigationSplitView` (sidebar + detail) plus the `.inspector` modifier (right panel).
  These are native, resizable columns that collapse correctly at small window sizes.
- Minimum window size 900×560. Column widths come from `AppLayout`.
- Main content tabs: **Agent** (Phase 1), **Files** (3), **Changes** (4), **Terminal** (4).
  Tabs that are not yet implemented show a placeholder that names their phase.

## State ownership

All navigation state lives in `WorkspaceViewModel`: selected project, session, tab, sidebar
and inspector visibility, palette presentation, and the folder importer. Views bind to it and
never hold navigation state themselves, which makes navigation testable (`WorkspaceViewModelTests`).

Selection rules:

- Selecting a project resumes its most recently updated session.
- Selecting a recent session from another project switches project first.
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
| ⌘P | Search Files… (Phase 3) |
| ⌘L | Change Model… |
| ⌘1 – ⌘4 | Agent / Files / Changes / Terminal |
| ⌃⌘S | Toggle sidebar |
| ⌥⌘I | Toggle inspector |
| ⌘, | Settings |
| ↩ / ⌥↩ | Send / new line in the composer |
| ⌘. | Stop the running agent |

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
