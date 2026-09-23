# 0016: Liquid Glass for floating layers, with a material fallback

**Status:** Accepted

## Context
The interface should feel premium and native. macOS 26 introduces Liquid Glass (`glassEffect`,
glass button styles, morphing between glass shapes). The app targets macOS 15 and later, and
Linear-like density requires opaque, legible content.

## Decision
- Use Liquid Glass for **floating layers only**: command palette, composer, approval banner,
  selected tab, chips and cards, and prominent buttons. The sidebar and inspector use the
  native system material.
- Keep content (transcript, code, lists) on opaque surfaces.
- Centralize every glass call in `Shared/DesignSystem/AppGlass.swift`, behind `if #available(macOS 26, *)`,
  with a `.regularMaterial` + hairline fallback. Keep the deployment target at macOS 15.

## Alternatives
- **Raise the deployment target to macOS 26**: simpler code, but drops macOS 15 users for a
  visual feature.
- **Custom blur (NSVisualEffectView wrappers)**: does not match the system's Liquid Glass and
  needs more code.
- **Glass everywhere**: hurts legibility and density, and goes against Apple's own guidance.

## Consequences
- The look is native on macOS 26 and consistent, though flatter, on macOS 15.
- Views never call `glassEffect` directly, so a future design change is a one-file change.
- Offscreen snapshots (`cacheDisplay`) cannot render glass, so visual checks of glass surfaces
  must be done on screen.
