# 0001: SwiftUI for the interface

**Status:** Accepted

## Context
The app is a native macOS productivity tool with a sidebar, inspector, overlays, rich lists
and frequent streamed updates. It must look native, support light/dark and accessibility, and
stay maintainable for years.

## Decision
Build the whole interface in SwiftUI (macOS 15+). Use AppKit only where SwiftUI has no
equivalent or is unreliable: `NSColor` dynamic providers for color tokens, `NSApp.appearance`
for the appearance switch, `NSWorkspace` for "Reveal in Finder". Wrap AppKit behind small,
documented helpers.

## Alternatives
- **AppKit only**: maximum control, but far more code for the same UI, and slower iteration.
- **Web UI (Electron/Tauri)**: not native. Rejected by the product goal.
- **SwiftUI on macOS 14**: loses `defaultScrollAnchor(_:for:)`, the `Synchronization` module
  and several fixes. The small audience gain is not worth it.

## Consequences
- Fast iteration, native controls, and accessibility built in.
- Some macOS behaviors need workarounds (text input, scroll anchoring). They are documented
  where they are used.
- Large transcripts need care (lazy stacks, no work in `body`). See docs/ai/streaming.md.
