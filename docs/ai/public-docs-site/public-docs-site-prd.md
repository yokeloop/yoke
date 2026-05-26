# Public docs site

**Tracking:** https://github.com/yokeloop/yoke/issues/15

## Problem Statement

`yoke` ships as a Claude Code plugin and a marketplace, but its public surface
is a single 16k `README.md`. Three audiences hit friction:

- **A potential user** discovering yoke from the Claude Code plugin marketplace
  has nowhere to land that explains, in scannable form, what each skill does,
  when it triggers, and how it fits into the workflow.
- **An existing user** can't link a teammate to "the page about `/plan`" —
  only to a section anchor in a long README.
- **A contributor** edits `SKILL.md`, then has to remember to also edit
  `README.md` and `CLAUDE.md` to keep the catalog in sync. Drift has already
  happened more than once.

## Solution

Publish a documentation site at `https://yokeloop.github.io/yoke` built with
Astro Starlight and deployed via GitHub Actions to the `gh-pages` branch.

The site has:

- A splash landing page with a hero, tagline, install CTA, and feature cards
  grouped by workflow stage.
- One page per skill, generated from that skill's `SKILL.md`. The page shows
  the description, trigger phrases, an example invocation, inputs/outputs, and
  a collapsible "Full instructions" block containing the raw `SKILL.md` body —
  so a reader sees exactly what Claude sees.
- Sidebar navigation grouping skills by workflow stage: Dev loop → Git →
  Analysis → Meta → Plugin dev.

Skill pages, the `## Skills` block in `README.md`, and the
`## Implemented skills` block in `CLAUDE.md` are all regenerated from
`skills/*/SKILL.md` by a new skill, **`/yoke:sync-docs`**. The same skill has
a `--check` verb that fails when these files have drifted; `/yoke-release`
runs `--check` first and refuses to ship if it's red.

## User Stories

1. As a developer browsing the Claude Code marketplace, I want to click
   through to a landing page for yoke, so that I can decide in 30 seconds
   whether it's worth installing.
2. As a developer evaluating yoke, I want to see each skill on its own page
   with a clear summary and example, so that I don't have to scroll a long
   README.
3. As a developer evaluating yoke, I want skills grouped by workflow stage,
   so that I understand which skills compose the "dev loop" and which are
   side-utilities.
4. As an existing yoke user, I want to share `yokeloop.github.io/yoke/skills/plan`
   with a teammate, so that I can point at "exactly this skill" instead of a
   README anchor.
5. As an existing yoke user, I want to read the full `SKILL.md` content
   right on the public page, so that I trust what the model is actually being
   told.
6. As an existing yoke user, I want a search box on the docs site, so that I
   can find a skill by triggering phrase without knowing its name.
7. As a contributor adding a new skill, I want to run one command after
   writing `SKILL.md`, so that the README catalog, the CLAUDE.md list, and the
   site page are all updated for me.
8. As a contributor, I want the release skill to refuse to publish if docs
   are out of date, so that I cannot accidentally ship a version with stale
   public pages.
9. As a contributor, I want sentinel-marker blocks in `README.md` and
   `CLAUDE.md` clearly labelled, so that I know which sections are
   machine-managed and must not be hand-edited inside the markers.
10. As a maintainer, I want the site to rebuild and redeploy automatically on
    every push to `main`, so that publishing docs requires no manual step
    after merge.
11. As a maintainer, I want the build to fail loudly if Astro can't compile,
    so that a broken site never goes live.
12. As a maintainer, I want the `gh-pages` branch to be exclusively managed
    by the deploy action, so that no one accidentally commits source files
    into the published artifact.
13. As a maintainer, I want the site assets isolated under `site/`, so that
    Claude Code's plugin scanner doesn't mistake docs files for plugin
    components.
14. As a maintainer, I want the docs toolchain on the same Node/pnpm runtime
    as the rest of the repo, so that contributors don't need Ruby or Python
    set up.
15. As a contributor running `/yoke-create`, I want the new skill to also
    refresh docs at the end of its pipeline, so that I never see a "skill
    exists but isn't in the catalog yet" state.
16. As a maintainer, I want the site to live at `yokeloop.github.io/yoke`
    with `base: '/yoke'`, so that I don't have to register or pay for a
    custom domain to launch.

## Implementation Decisions

### Stack and deployment

Per [ADR 0001](../../adr/0001-docs-site-on-astro-starlight.md):

- **Astro Starlight** as the docs framework.
- Source under `site/`, separate from plugin component directories.
- `astro.config.mjs`: `site: 'https://yokeloop.github.io'`, `base: '/yoke'`.
- Pagefind search (Starlight default) — no Algolia.
- Build via GitHub Actions on push to `main`; deploy `dist/` to the
  `gh-pages` branch via `actions/upload-pages-artifact` +
  `actions/deploy-pages` (or `peaceiris/actions-gh-pages` — implementer's
  call).
- Site language: English only.

### Site structure

- Landing page (`src/content/docs/index.mdx`) uses Starlight's `splash`
  template: hero with title, tagline, primary CTA "Install" + secondary CTA
  "Browse skills"; feature cards grouped by workflow stage.
- Per-skill pages live at `src/content/docs/skills/<name>.mdx`.
- Sidebar groups (configured in `astro.config.mjs`):
  - **Dev loop** — task, plan, do, review, fix
  - **Git** — gca, gp, pr, gst
  - **Analysis** — explore, grill, grill-docs, prd, issues
  - **Meta** — bootstrap, help, handoff
  - **Plugin dev** — yoke-create, yoke-release
- A small set of generic pages: "What is yoke?", "Install", "Concepts"
  (skills vs. commands vs. agents).

### Per-skill page shape

Each generated page contains, top to bottom:

1. Title (`/yoke:<name>`).
2. One-line description (from `description:` in the SKILL.md frontmatter).
3. Trigger phrases — the literal phrases pulled out of the description.
4. A "Use it" example, if one is derivable from the SKILL.md body or the
   skill's command file under `commands/<name>.md`.
5. Inputs / outputs / side effects (best-effort extraction).
6. A `<details>` block titled "Full instructions" containing the raw SKILL.md
   body verbatim.
7. Footer link: "View source on GitHub" → the canonical SKILL.md path.

### Single source of truth

Per [ADR 0002](../../adr/0002-sync-docs-skill.md):

- A new shipped skill, **`/yoke:sync-docs`**, regenerates:
  1. `site/src/content/docs/skills/<name>.mdx` per skill.
  2. The block between `<!-- yoke:skills:start -->` and
     `<!-- yoke:skills:end -->` markers in `README.md`.
  3. The block between the same markers in `CLAUDE.md`.
- The skill has a **check verb** (`/yoke:sync-docs --check` or equivalent
  argument) that exits non-green when current files don't match what sync
  would generate.
- `/yoke-release` invokes the check verb as its first gate. On failure the
  release halts and the author is asked to run sync, review the diff, commit,
  then retry.
- `/yoke-create` invokes the sync verb at the end of its pipeline.

### Sentinel markers

- Open: `<!-- yoke:skills:start -->`
- Close: `<!-- yoke:skills:end -->`
- The skill must refuse to write when markers are missing or unbalanced, and
  point the user at the affected file.
- The markers themselves are added once, by hand, in this PRD's
  implementation phase.

### Constraints inherited from existing repo conventions

- Content language: English. Skills' SKILL.md is already in English.
- File and directory names: kebab-case.
- Versioning: the plugin's `plugin.json` remains the source of truth; the
  docs site does not version itself in this iteration (always reflects
  `main`).

## Testing Decisions

The unit under verification is a Claude Code skill, which is non-deterministic.
That rules out unit tests; verification is by **check-mode round-trip** plus
**manual QA**.

What we verify:

- **Round-trip idempotence.** After `/yoke:sync-docs` runs, a second
  `/yoke:sync-docs --check` immediately afterward must be green. If it isn't,
  the skill is not deterministic enough — fix the skill before relying on the
  release gate.
- **Drift detection.** Hand-edit `README.md` between the sentinels, then run
  `/yoke:sync-docs --check`. It must exit non-green and point at the file.
- **Marker safety.** Remove a sentinel marker from `CLAUDE.md` and run sync.
  It must refuse to write rather than silently producing garbage.
- **Site build.** `pnpm --filter site build` must compile without errors after
  sync. `pnpm --filter site dev` must serve a working site locally.
- **Production deploy.** A push to `main` triggers the workflow; the workflow
  succeeds; the resulting `gh-pages` branch contains a `dist/` tree that
  loads at `yokeloop.github.io/yoke` with sidebar, search, and at least one
  skill page rendering correctly.

What makes a good check here: it asserts a user-visible outcome (site loads,
release gate halts on drift) rather than the shape of intermediate files.

Prior art in the repo: there is no comparable test scaffold today. The
`format:check` script in `package.json` is the closest analogue — a
deterministic command that exits non-green when something is wrong; the
`docs:check` verb on `/yoke:sync-docs` plays the same role for documentation.

Out of scope for verification:

- Snapshot tests over generated MDX. Considered, rejected: the skill is not
  deterministic, so snapshots would just produce noise.
- A parallel `pnpm docs:check` helper for CI. Considered, deferred: the
  release gate covers the high-value case; CI-side check can be added later
  when warranted.

## Out of Scope

- Custom domain. Launch on `yokeloop.github.io/yoke`. If desired later, add
  a `CNAME` to `site/public/` and update DNS — non-breaking.
- Internationalization. English only for now. Starlight i18n can be enabled
  later without a rewrite.
- Versioned docs (per-plugin-version archives). The site always reflects
  `main`.
- Marketing pages beyond the landing splash: no blog, no changelog page, no
  comparison page.
- Algolia DocSearch. Pagefind (Starlight default) is enough.
- Telemetry / analytics. Add later if needed.
- Migrating `README.md` content elsewhere. The README stays a full document;
  the site duplicates the skill catalog (via sync), nothing else.
- A pnpm-script equivalent of `/yoke:sync-docs`. The skill is the only
  entry point.

## Further Notes

- Existing `docs/` directory is **not** the site root — `docs/` continues to
  hold reference markdown for the plugin internals (notify, github-issues,
  domain-docs, ADRs). Site sources live in `site/` to make this distinction
  obvious.
- `/yoke-release` integration is a behavior change to a shipped skill;
  release-skill consumers should be told in the changelog that the gate now
  exists.
- The two ADRs that drive this PRD are
  [0001-docs-site-on-astro-starlight](../../adr/0001-docs-site-on-astro-starlight.md)
  and [0002-sync-docs-skill](../../adr/0002-sync-docs-skill.md). If
  implementation diverges from either, update the ADR first.
- Break down implementation tickets via `/yoke:issues` against this PRD;
  natural vertical slices: (a) Astro scaffold + manual landing page, (b)
  `/yoke:sync-docs` write mode + sentinels in README/CLAUDE.md, (c) check
  mode + release-skill gate, (d) GitHub Actions deploy, (e) `/yoke-create`
  tail hook.
