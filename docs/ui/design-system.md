# Design system

Inspired by Linear, not copied: **premium, minimal, native, dense but readable.** The
interface should disappear behind the work.

## Principles

- **Hierarchy through type and tone, not decoration.** Three text tones (primary, secondary,
  tertiary) do most of the work.
- **Hairlines over boxes.** Structure comes from 1 pt borders at low opacity, not shadows or cards.
- **One accent, used sparingly.** A muted indigo marks the single primary action and the
  active state. Status colors are reserved for status.
- **Density.** 13 pt body, 28 pt rows, 4 pt grid.
- **Quiet motion.** 120–220 ms, ease-out, disabled under Reduce Motion.

Avoided: gradients, large cards, large colored buttons, heavy shadows, glassy “AI startup”
aesthetics, dashboards of widgets.

## Tokens (`App/Shared/DesignSystem/`)

| Token | Values |
|---|---|
| `AppColors` | `background`, `sidebar`, `surface`, `surfaceRaised`, `hover`, `selection`, `scrim`, `border`, `borderStrong`, `textPrimary/Secondary/Tertiary`, `accent`, `accentSubtle`, `success`, `warning`, `danger` |
| `AppTypography` | `title` (15 semibold), `headline` (13 medium), `body` (13), `callout` (12), `caption` (11), `sectionHeader`, `code` (mono 12), `shortcut` |
| `AppSpacing` | `xxs 2`, `xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 24`, `xxl 32` |
| `AppRadius` | `small 4`, `medium 6`, `large 8`, `overlay 12` |
| `AppBorders` | `hairline 1` |
| `AppShadow` | `overlay` (floating layers only) |
| `AppAnimation` | `quick`, `standard`, `overlay`, and `.appAnimation(_:value:)`, which respects Reduce Motion |
| `AppLayout` | column widths, readable width (760), palette width (560), row height (28) |

### Color decisions

- Colors are **dynamic** (`NSColor(name:dynamicProvider:)`). They resolve per appearance at
  draw time, so switching light/dark/Increase Contrast needs no view reload.
- Dark background is `#0F1012`, not pure black, so borders and surfaces stay visible.
- Borders become much stronger under Increase Contrast (alpha 0.35–0.5).
- Text contrast is at least 4.5:1 on backgrounds in both modes (see [accessibility](accessibility.md)).

### Typography decisions

Tokens map to system **text styles** (`.body`, `.callout`, …) rather than fixed sizes. That
keeps SF Pro metrics and follows any future system text-size setting.

## Using tokens

```swift
Text(title)
    .font(AppTypography.headline)
    .foregroundStyle(AppColors.textPrimary)
    .padding(AppSpacing.md)
```

Literal colors, font sizes or spacings in feature views are review blockers. If a value is
missing, add a token.
