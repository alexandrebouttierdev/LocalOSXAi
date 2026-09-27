# 0024: Settings as a screen of the main window, not a Settings window

**Status:** Accepted

## Context
Settings lived in the standard macOS Settings window (⌘,), a small separate window with a tab
bar. It did not share the app's look (sidebar, inset panel, Linear surfaces), it was easy to lose
behind the main window, and the Providers page, with custom servers, outgrew its fixed width.
The user asked for a settings screen instead, as in Linear.

## Decision
- ⌘, (the menu item, the palette command and the sidebar's Settings button) shows
  `SettingsScreen` **in place of the workspace** in the main window: a sidebar with “Back to app”
  and the sections, and the selected section on the inset panel, under its title.
- The state lives in `WorkspaceViewModel` (`isSettingsPresented`, `settingsSection`), like the
  rest of the navigation, so it is tested without UI. Esc and “Back to app” return to the
  workspace as it was left; commands that lead to work (a tab, a new session, file search)
  return too. Commands that do not (toggling the inspector) keep the screen.
- There is no `Settings` scene: the app menu's “Settings…” item is provided by a
  `CommandGroup(replacing: .appSettings)`.

## Alternatives
- **Keep the Settings window, restyled**: stays a separate, small window with the system tab bar.
- **A sheet over the workspace**: modal and cramped for the Providers page, and it hides the
  workspace without being navigable.
- **A settings tab next to Agent/Files/…**: settings are global, while those tabs belong to the
  selected project.

## Consequences
- Settings pages get the full window and the app's visual language.
- The workspace keeps running behind the screen: an agent run continues while settings are open.
- `WorkspaceViewModel.perform` no longer returns an effect for views to carry out: opening
  settings is plain state.
