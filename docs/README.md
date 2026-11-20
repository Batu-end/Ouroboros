# Ouroboros landing page

Plain static site: `index.html`, `style.css`, `script.js`, `favicon.svg`, `assets/`, `.nojekyll`. No build step. All paths are relative, so it works under `username.github.io/repo-name/`.

## Deploy (GitHub Pages)

Option A — inside the app repo (matches the Open Graph URLs as written):

1. The site files live in `Ouroboros/docs/` (next to `images/`, which the repo README uses).
2. Commit and push to `main`.
3. Repo → Settings → Pages → Source: "Deploy from a branch" → Branch `main`, folder `/docs` → Save.
4. Live in a minute or two at `https://batu-end.github.io/Ouroboros/`.

Option B — its own repo: push this folder to the root of `main`, pick folder `/ (root)` in step 3, and update `og:url` / `og:image` in `index.html` to the new address.

Preview locally: `python3 -m http.server` in this folder, then open http://localhost:8000.

## Placeholders and things to check

Already filled from the app repo: username `Batu-end`, repo `Ouroboros`, version `v0.1.0`, macOS 14+.

- **Version**: `v0.1.0` appears in 3 `data-version` spans (hero fine print, beta note, footer). Bump on each release.
- **Tagline and subline**: marked `EDIT` in the hero.
- **Feature copy**: marked `EDIT` in Features. Each claim comes from the README; re-check if the app changes (15% default, 60 s floor, 60-day history, 0% idle CPU, no network code).
- **Screenshot**: the hero shows an HTML mock. To swap in a real image, follow the `SCREENSHOT SLOT` comment (`assets/screenshot-working.png` is already there).
- **Social preview**: `og:image` uses the 503×640 screenshot with a `summary` card. For a wide preview, add a 1200×630 `og-image.png` and switch `twitter:card` to `summary_large_image`.
- **Open Graph URLs**: absolute, assume `batu-end.github.io/Ouroboros/`. Change if you use Option B or a custom domain.
- **Notarization note**: the beta section explains "Open Anyway". Delete that paragraph once the app is notarized.
- **Beta facts**: "tested on one machine (Apple silicon, macOS 26), Intel never run". Update as that changes.
- **Footer**: "MIT licensed · Made by Batu".
- **Favicon**: a simple ring mark (`favicon.svg`), not the app icon, because the README says the icon's rights are unverified.
