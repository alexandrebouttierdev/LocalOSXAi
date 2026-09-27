# Landing page

`index.html` is the project's website, published on GitHub Pages at
<https://alexandrebouttierdev.github.io/LocalOSXAi/> by `.github/workflows/pages.yml` whenever
`site/` changes on `dev`.

- One file, Tailwind CSS v4 from its CDN build (`@tailwindcss/browser`), no build step.
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

To preview locally, open `index.html` in a browser.
