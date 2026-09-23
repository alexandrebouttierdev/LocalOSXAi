# Accessibility

Accessibility is a requirement from the first phase, not a polish item.

## Implemented

| Area | How |
|---|---|
| Keyboard navigation | Native `List` sidebar (arrows, type-select), menu shortcuts for every command, palette ↑/↓/↩/⎋, composer ↩/⌥↩/⌘. |
| VoiceOver | Labels on icon-only controls (“Toggle Inspector”, “Command palette”, add buttons); header traits on section titles; combined elements for rows; palette rows expose the selected trait and their shortcut or disabled reason as a hint; the context meter speaks “38.4 thousand of 100 thousand context tokens used” |
| State not by color alone | `StatusBadge` pairs icon and text; tool call status has distinct icons and a spoken status; “Over budget” in text; failed and stopped messages have text badges |
| Contrast | Text tokens meet 4.5:1 on backgrounds in light and dark (tertiary text was tuned for this: `#7C7F89` on `#0F1012`, `#6E717A` on `#F7F7F8`) |
| Increase Contrast | Border tokens switch to much stronger alpha under the high-contrast appearances |
| Reduce Motion | `.appAnimation(_:value:)` disables animations when Reduce Motion is on |
| Text size | Typography tokens use system text styles instead of fixed sizes |

## Rules for new UI

- Every icon-only button has `accessibilityLabel` and a `.help` tooltip.
- Custom selectable controls set `.isSelected`.
- Decorative images are `accessibilityHidden(true)`.
- Never convey meaning with color alone.
- Everything reachable with the mouse is reachable with the keyboard.

## Phase 6 audit

A full audit with Accessibility Inspector and VoiceOver: focus order, rotor headings, modal
focus trapping for the palette, and announcements for streamed responses (announce completion,
not every token).
