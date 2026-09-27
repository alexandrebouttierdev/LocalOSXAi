# 0023: Linear's visual language: Inter, Linear's palette, opaque surfaces

**Status:** Accepted (supersedes [0016](0016-liquid-glass-with-fallback.md))

## Context
The app was “Linear-inspired” but did not feel as premium as Linear. Screenshots showed why:
Liquid Glass and the native sidebar material let the desktop wallpaper tint the sidebar, the
inspector and the floating layers (a blue cast in the inspector), capsules and large radii read
as “iOS” rather than precise, SF Pro at system weights lacked Linear's texture, and errors were
loud red boxes. Linear itself is opaque, near-black and neutral, set in Inter, with 6–12 pt
radii, hairline borders and one indigo accent.

## Decision
- **Opaque surfaces.** Window, sidebar, inspector and toolbar sit on the `background` ground;
  floating layers use `surfaceRaised`, a hairline border and a soft shadow (`appFloating`).
  No `glassEffect`, no materials. `AppGlass.swift` is replaced by `AppSurface.swift`.
- **Linear's palette**: ground `#08090A`, panel `#0F1011`, raised `#18191C`, text `#F7F8F8` /
  `#8A8F98` / `#7C7F89`, accent `#5E6AD2`, status `#4CB782` / `#F2994A` / `#EB5757`. Text keeps
  WCAG AA; the lowest tone is lighter than Linear's own `#62666D`, which fails 4.5:1.
- **Inter** (variable, SIL Open Font License) bundled in the app and registered through
  `ATSApplicationFontsPath`, at Linear's sizes (13 pt body), and set as the window's default
  font. Code stays in the system monospaced face.
- **Shapes and controls**: rounded rectangles of 6, 8 or 12 pt instead of capsules; 28 pt
  primary, secondary and square icon buttons; text tabs with a raised selection; neutral user
  bubbles; errors as neutral cards with a red icon.

## Alternatives
- **Keep Liquid Glass, tune tints**: the desktop still shows through, which is the opposite of
  Linear's calm, uniform surfaces, and glass cannot be verified in offscreen snapshots.
- **SF Pro with tighter tracking**: native and close, but not Linear's type; the font is 880 KB.
- **Linear's exact lowest text tone**: fails accessibility for body text.

## Consequences
- The look no longer depends on the macOS version or the wallpaper, and Reduce Transparency has
  nothing left to change.
- Views call `appFloating` and `appButton` instead of glass APIs; `SecondaryButtonStyle` and
  `IconButtonStyle` join the button styles.
- The app ships a font and its license (`App/Resources/Fonts/Inter-LICENSE.txt`). A test fails
  if the font is not bundled or registered, since SwiftUI would otherwise fall back to SF Pro
  silently.
- The design was written without running the app (see the commit): a visual pass with
  `make ui-snapshots` is the next step.
