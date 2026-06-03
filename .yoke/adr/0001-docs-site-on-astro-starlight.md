# 1. Docs site on Astro Starlight, deployed to GitHub Pages from `site/`

Date: 2026-05-26

## Status

Accepted — deploy mechanism amended on 2026-05-26 (see Amendment below).

## Context

`yoke` is distributed as a Claude Code plugin. The README has grown to ~16k and
documents every skill in a flat list. We want a public site at
`yokeloop.github.io/yoke` so users can browse skills, read "how it works"
without cloning the repo, and discover yoke from the Claude Code plugin
marketplace.

Constraints:

- The site must be hostable on GitHub Pages (no paid infra).
- Skill content already lives in `skills/*/SKILL.md` — we don't want a separate
  hand-maintained copy that drifts.
- The audience is developers; clean nav, search, and code blocks matter more
  than marketing visuals.
- We do not want to introduce a non-JS toolchain (Ruby, Python) for the docs
  pipeline — the rest of the project is Node/pnpm.

Alternatives considered:

- **Jekyll + just-the-docs** — native to GH Pages, no build action needed.
  Rejected because it pulls in Ruby and the visual baseline is dated.
- **MkDocs Material** — popular, polished. Rejected because it pulls in
  Python; ecosystem mismatch with the rest of the project.
- **Plain HTML** — full control, no deps. Rejected because navigation, search,
  and sidebar would have to be hand-rolled.

## Decision

- Use **Astro Starlight** as the docs framework.
- Sources live under `site/` (separate from the plugin tree so plugin scanners
  don't see them as components).
- Build via **GitHub Actions** on push to `main`, deploy the resulting `dist/`
  to the `gh-pages` branch (which GH Pages serves).
- Astro config: `site: 'https://yokeloop.github.io'`, `base: '/yoke'`.
- Landing page uses Starlight's **splash hero + feature cards** template.
- Sidebar groups skills **by workflow stage** (Dev loop → Git → Analysis →
  Meta → Plugin dev), not alphabetically.

## Consequences

Positive:

- One Node toolchain across the repo.
- Search (Pagefind), dark mode, MDX, sidebar nav out of the box.
- Building from `main` keeps the working branch clean of build artifacts.

Negative / costs:

- Adds an Astro dependency tree to the repo (only under `site/`).
- A GH Actions workflow becomes part of the release surface — a broken build
  blocks docs updates.
- The `gh-pages` branch is force-pushed on each deploy; never commit to it
  manually.

Follow-ups:

- See [0002-sync-docs-skill.md](0002-sync-docs-skill.md) for how skill content
  flows from `SKILL.md` into the site.

## Amendment — 2026-05-26: deploy via Pages-from-Actions, no `gh-pages` branch

The Decision section above says "deploy the resulting `dist/` to the `gh-pages`
branch". The implementation in `.github/workflows/docs.yml` uses Pages-from-
Actions instead — `actions/upload-pages-artifact` + `actions/deploy-pages` —
which publishes from a job artifact rather than a branch. No `gh-pages` branch
is created.

Reasons for the change:

- Modern recommended GitHub Pages flow; `peaceiris/actions-gh-pages` is now a
  third-party alternative rather than the default.
- Keeps the repository's branch list free of a force-pushed build artifact.
- The deploy job runs in the `github-pages` environment with `id-token: write`
  for OIDC, which is harder to express with branch-based deploys.

The one-time repo setting becomes Settings → Pages → Source = **GitHub
Actions** (was: Deploy from branch: gh-pages).

This amendment supersedes the third bullet of the Decision section and the
"force-push" reference in the second Negative consequence. The rest of the
decision (Astro Starlight, `site/` layout, sidebar grouping, Astro config
values, GH Actions trigger) stands unchanged.
