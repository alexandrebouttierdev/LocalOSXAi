# 0025: A flat sidebar with custom rows instead of `NavigationSplitView` and `List`

**Status:** Accepted

## Context
After the move to Linear's visual language ([ADR 0023](0023-opaque-linear-surfaces.md)), the
sidebar still did not look like Linear's. On macOS 26, `NavigationSplitView` draws its sidebar
as a floating Liquid Glass panel with its own rounded edge, and a `List` selection always takes
the system accent: the selected session was the most saturated thing on screen. Neither can be
turned off with public SwiftUI API.

## Decision
- `SidebarLayout` (Shared) replaces `NavigationSplitView` in the workspace and the settings
  screen: an `HStack` of the sidebar, an invisible resize edge (drag, 200–320 pt, remembered in
  `@AppStorage`) and the detail, all on the `background` ground. The toolbar gets its own
  sidebar button; the existing Toggle Sidebar command drives `isSidebarVisible`.
- Rows are `SidebarRow` buttons: 28 pt, 6 pt corners, `hover` on hover, `selection` (7% white)
  when selected, primary text. Context menus are unchanged.
- Keyboard: ↑/↓ move the selection through `WorkspaceViewModel.sidebarItems` /
  `selectAdjacentSidebarItem`, which is unit-tested; clicking a row focuses the list.

## Alternatives
- **Keep `NavigationSplitView`, style the list**: the glass panel and the accent selection
  remain; they are what the user saw as “not Linear”.
- **An `NSSplitViewController` wrapper**: native resizing and collapse, but AppKit bridging for a
  look that plain SwiftUI already gives.

## Consequences
- The sidebar looks the same on macOS 15 and 26, and matches the inset content panel.
- Lost from `List`: type-select, and the system's collapse-by-dragging. Tab still reaches every
  row, which is a labelled button with the selected trait for VoiceOver.
