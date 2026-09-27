# Design system

Linear's visual language on a native macOS app: **premium, minimal, dense but readable.** The
interface should disappear behind the work.

## Principles

- **Hierarchy through type and tone, not decoration.** Three text tones (primary, secondary,
  tertiary) do most of the work.
- **Hairlines over boxes.** Structure comes from 1 pt borders at low opacity. Shadows only under
  layers that float (composer, palette, banner).
- **One accent, used sparingly.** A muted indigo marks the single primary action and the
  active state. Status colors are reserved for status.
- **Density.** 13 pt body, 28 pt rows, 4 pt grid.
- **Quiet motion.** 120–220 ms, ease-out, disabled under Reduce Motion.

## Layout

The reference mockup (Linear style) is a dark ground holding the sidebar, with the content on
an **inset panel**: `surface`, 12 pt corners (`AppRadius.panel`), a `hairline` outline and 8 pt
of ground around it. The window has **no title bar**: the traffic lights float over the sidebar,
and the panel starts with its own header row (the view's icon, “project › session”, the
inspector toggle) above a hairline, like a Linear issue. The sidebar is Linear's: the project
switcher row with search and new-session icons, the project's views as icon rows (Files,
Changes with its count, Terminal), then the sessions in collapsible date sections (“Today ▾”),
each row led by an icon for its agent (bubble, spinner, raised hand), and a footer with
Settings and which model servers answered (their logos and “Ollama connected”). The inspector
lists the model (with its provider's logo), the context (usage meter and length) and Git.

Provider logos (Ollama, LM Studio) come from `@lobehub/icons-static-svg` (MIT); the marks belong
to their owners and identify the providers only. They are vector template images
(`ProviderOllama`, `ProviderLMStudio` in `Assets.xcassets`), so they take the text color, like
SF Symbols. The composition root sets them on `ProviderDescriptor.logo`; custom servers show
`server.rack` (`ProviderLogo`).

Avoided: gradients, large cards, large colored buttons, heavy shadows, decorative “AI startup”
aesthetics, dashboards of widgets.

One exception, for feedback only: `ActivityIndicator`, shown while the model loads, thinks or
decides its next step, sweeps a light across its title (text colors, accent highlight). It
tells the user a slow local model is still working. It never decorates, and with Reduce Motion
it is still.

## Surfaces

Every surface is **opaque**, as in Linear: nothing takes the tint of the desktop behind the
window, so contrast is the same everywhere and the interface reads as one calm plane
([ADR 0023](../decisions/0023-opaque-linear-surfaces.md), which replaced Liquid Glass).

| Surface | Treatment |
|---|---|
| Window, sidebar, inspector | `background` ground (`#08090A` in dark mode) |
| Content panel | `surface` (`#0F1011`), inset on the ground, 12 pt corners, hairline outline |
| Command palette, composer, approval banner (warning wash) | `appFloating(in:)`: `surfaceRaised`, `border`, soft `shadow` |
| Model card, recent projects, search field, suggestion chips, empty-state icon | `appFloating(in:elevated: false)`: same, without shadow (they sit in the content) |
| Selected tab | A raised rounded rectangle that slides between text tabs |
| Buttons | `.primary` (indigo fill, the one main action), `.secondary` (raised, bordered), `.icon(prominent:)` (square send/stop), `.subtle` (text with hover) |
| Transcript, messages, code blocks, tool rows, lists | On the panel; user messages are raised neutral bubbles, errors a neutral card with a red icon and a faint red wash |

`AppSurface.swift` holds the surface modifier and `appButton(prominent:)`; `ButtonStyles.swift`
the button styles. Shapes are rounded rectangles (6, 8 or 12 pt): no capsules, except
progress bars and count badges.

## Motion

- Messages fade in and rise 8 pt as they arrive. The command palette scales from 97% with a fade.
- The agent avatar's sparkles animate while the agent works (`symbolEffect(.variableColor)`),
  and a pending approval pulses.
- Everything uses `AppAnimation` tokens and is disabled or reduced under Reduce Motion.

## Tokens (`App/Shared/DesignSystem/`)

| Token | Values |
|---|---|
| `AppColors` | `background` (ground), `surface` (content panel), `surfaceRaised`, `hover`, `selection`, `scrim`, `shadow`, `hairline`, `border`, `borderStrong`, `textPrimary/Secondary/Tertiary`, `accent` (fills), `accentText` (accent as text), `accentSubtle`, `success`, `warning`, `danger`, `projectPalette`, `Hue` (Linear's label hues: blue, teal, purple, orange, yellow, green, pink — property icons and label dots only, always next to a word), `codeBackground` |
| `AppTypography` | Inter: `display` (22 semibold), `title` (15 semibold), `headline` (13 medium), `body` (13), `callout` (12), `caption` (11), `sectionHeader` (11 medium), `shortcut`; `code` is the system mono (12) |
| `AppSpacing` | `xxs 2`, `xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 24`, `xxl 32` |
| `AppRadius` | `small 4`, `medium 6`, `large 8`, `panel 12`, `overlay 12`, `bubble 10`, `composer 12` |
| `AppBorders` | `hairline 1` |
| `AppAnimation` | `quick`, `standard`, `overlay`, and `.appAnimation(_:value:)`, which respects Reduce Motion |
| `AppLayout` | column widths, readable width (760), palette width (560), row and button height (28) |

### Color decisions

- Colors are **dynamic** (`NSColor(name:dynamicProvider:)`). They resolve per appearance at
  draw time, so switching light/dark/Increase Contrast needs no view reload.
- Linear's dark palette: ground `#08090A`, content panel `#0F1011`, raised `#18191C`; text
  `#F7F8F8`, `#8A8F98` and `#7C7F89` (the lowest tone that keeps 4.5:1 for body text); borders
  at 5–13% white. Not pure black, so hairlines and surfaces stay visible.
- The accent has two tokens. `accent` (Linear's `#5E6AD2`) is a fill that carries white text
  (primary button, badges, meter; 4.7:1). `accentText` (`#828FFF` in dark mode) is the accent
  used as text or a thin glyph, where the fill color would be under 4.5:1 on dark surfaces.
- Status colors are Linear's too: green `#4CB782`, orange `#F2994A`, red `#EB5757`.
- Borders become much stronger under Increase Contrast (alpha 0.35–0.5).
- Text contrast is at least 4.5:1 on backgrounds in both modes (see [accessibility](accessibility.md)).

### Typography decisions

The typeface is **Inter**, Linear's, bundled as `InterVariable.ttf` (SIL Open Font License,
`App/Resources/Fonts`) and registered with `ATSApplicationFontsPath`. Its optical-size axis gives
the 22 pt display size Inter Display's tighter shapes. Each token is relative to a system text
style, so it scales with it. The window and Settings set `AppTypography.body` as their default
font, so controls without an explicit font use Inter too. If the font failed to load, SwiftUI
would fall back to SF Pro at the same sizes; a test checks that it is bundled and registered.
Code stays in the system monospaced face.

## Using tokens

```swift
Text(title)
    .font(AppTypography.headline)
    .foregroundStyle(AppColors.textPrimary)
    .padding(AppSpacing.md)
```

Literal colors, font sizes or spacings in feature views are review blockers. If a value is
missing, add a token.
