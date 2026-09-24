# Accessibility

Accessibility is a requirement from the first phase, not a polish item.

## Implemented

| Area | How |
|---|---|
| Keyboard navigation | Native `List` sidebar (arrows, type-select), menu shortcuts for every command, palette ↑/↓/↩/⎋, composer ↩/⌥↩/⌘. |
| VoiceOver | Labels on icon-only controls (“Toggle Inspector”, “Command palette”, add buttons); header traits on section titles; combined elements for rows; palette rows expose the selected trait and their shortcut or disabled reason as a hint; the context meter speaks “38.4 thousand of 100 thousand context tokens used” |
| State not by color alone | `StatusBadge` pairs icon and text; tool call status has distinct icons and a spoken status; “Over budget” in text; failed and stopped messages have text badges |
| Contrast | Text tokens meet 4.5:1 on backgrounds in light and dark (tertiary text was tuned for this: `#7C7F89` on `#111214` (4.7:1), `#696C75` on `#F4F4F5` (4.8:1)) |
| Increase Contrast | Border tokens switch to much stronger alpha under the high-contrast appearances |
| Announcements | VoiceOver announces the end of a run (finished, paused at the step limit, stopped, failed with the reason) and each approval request, never individual tokens (`AgentViewModel.announcement`) |
| Headings | Each agent turn's “Agent” header is a heading, so the rotor jumps between turns |
| Modal palette | While the command palette is open, the rest of the window is hidden from VoiceOver and the palette has the modal trait |
| Reduce Motion | `.appAnimation(_:value:)` disables animations when Reduce Motion is on. Message transitions fall back to a plain fade. Symbol effects honor the setting natively |
| Reduce Transparency | Liquid Glass and the fallback materials become opaque automatically |
| Text size | Typography tokens use system text styles instead of fixed sizes |

## Rules for new UI

- Every icon-only button has `accessibilityLabel` and a `.help` tooltip.
- Custom selectable controls set `.isSelected`.
- Decorative images are `accessibilityHidden(true)`.
- Never convey meaning with color alone.
- Everything reachable with the mouse is reachable with the keyboard.

## Phase 6 audit

Done in code and covered by tests where testable: run and approval announcements, turn
headings, modal palette. **Not done:** a manual pass with Accessibility Inspector and VoiceOver
on a real window (focus order, labels as spoken). It needs a person at the machine; findings
go into this file.
