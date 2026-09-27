# Landing page

`index.html` is the project's website, published on GitHub Pages at
<https://alexandrebouttierdev.github.io/LocalOSXAi/> by `.github/workflows/pages.yml` whenever
`site/` changes on `dev`.

- Two pages, English (`index.html`) and French (`fr/index.html`), same markup: **change both**.
  Tailwind CSS v4 from its CDN build (`@tailwindcss/browser`), no build step.
- Language: flag buttons (United Kingdom, France; SVG, since emoji flags do not show on
  Windows) switch pages and remember the choice. On a first visit, a browser set to French goes
  to `/fr/`; a choice made with the flags always wins. `hreflang` links tell search engines.
  The app's own interface stays in English in the window mock, as the app is in English.
- Provider logos (Ollama, LM Studio, vLLM) are inline SVGs from `@lobehub/icons-static-svg`
  (MIT, [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)); servers without a logo there
  (llama.cpp, Jan, LocalAI) show a neutral server icon rather than an invented one.
- The app's design system: the colors of `AppColors` (light and dark), Inter, hairlines.
  Dark or light follows the visitor's system until they choose with the toggle, remembered on
  their device.
- Animations: staggered entrance of the hero, sections rising into view as they are scrolled
  to, context meters filling, the approval card sliding in. All of them stop with the system's
  Reduce Motion setting, and the page shows everything without JavaScript.
- Download buttons point to the latest GitHub release
  ([docs/code/releasing.md](../docs/code/releasing.md)).

**One-time setup**: repository Settings › Pages › Build and deployment › Source: *GitHub
Actions*. Then run the “Pages” workflow once (Actions tab) or change a file in `site/`.
Until then, GitHub's own “pages build and deployment” publishes the README on every push; the
workflow also runs when that build ends (`page_build`), so the landing page is published again
right after it.

To preview locally, open `index.html` in a browser.
