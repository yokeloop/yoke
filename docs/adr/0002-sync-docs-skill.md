# 2. Single source of truth via `/yoke:sync-docs` skill

Date: 2026-05-26

## Status

Accepted

## Context

After [ADR 0001](0001-docs-site-on-astro-starlight.md), skill content lives in
three places that can drift:

1. `skills/<name>/SKILL.md` — the canonical instructions Claude Code loads.
2. `README.md` — the `## Skills` section listed for GitHub readers.
3. `site/src/content/docs/skills/<name>.md` — the public docs page.

The CLAUDE.md `Implemented skills` section is a fourth.

We need a way to keep these aligned without forcing the author to edit four
files for every skill change, and we want a **pre-release validation gate** so
nothing ships with stale docs.

Alternatives considered:

- **pnpm script (`pnpm docs:sync`)** — deterministic, CI-friendly. Rejected
  because the author preferred Claude-driven sync; the skill can adapt SKILL.md
  prose (which is written for an LLM) into reader-facing prose, which a parser
  can't.
- **Astro glob-import from `../skills/**/SKILL.md`\*\* — no script needed.
  Rejected because the LLM-instruction tone leaks into the public site
  verbatim and README still drifts.
- **Hand-edit all four files** — status quo. Rejected: it's already drifted
  once.

## Decision

Add a new skill, **`/yoke:sync-docs`**, that:

1. Reads every `skills/*/SKILL.md` plus their frontmatter.
2. Writes one MDX page per skill into `site/src/content/docs/skills/<name>.mdx`.
   Each page has a hand-readable summary (description, triggers, example,
   inputs/outputs) and a collapsible "Full instructions" block with the raw
   SKILL.md.
3. Regenerates the `## Skills` section in `README.md` between sentinel
   markers (`<!-- yoke:skills:start -->` … `<!-- yoke:skills:end -->`).
4. Regenerates the `## Implemented skills` list in `CLAUDE.md` between the
   same kind of markers.
5. Has a **check mode** (`/yoke:sync-docs --check`, or an explicit verb) that
   diffs current files against what sync would generate and exits non-zero if
   they disagree. Intended to be called from `/yoke-release` as a release
   gate.

The skill itself lives in `skills/sync-docs/SKILL.md` and is shipped with the
plugin (not local-only) so downstream contributors can run it.

`/yoke-release` invokes `/yoke:sync-docs --check` early; if check fails, the
release halts and the author runs `/yoke:sync-docs` to regenerate, reviews
the diff, commits, then retries the release.

## Consequences

Positive:

- `SKILL.md` is the single source of truth.
- README, CLAUDE.md and the site can't ship out of sync — the release skill
  refuses.
- The site's "How it works" block is always the literal SKILL.md, so users
  see exactly what Claude sees.

Negative / costs:

- Sentinel-marker blocks in README/CLAUDE.md must not be hand-edited inside
  the markers.
- A Claude run is needed to refresh docs; CI on its own can't fix drift, only
  detect it via the check verb (which itself is a Claude run unless we add a
  parallel pnpm helper later).
- Adding a new skill now has two steps: write `SKILL.md`, run
  `/yoke:sync-docs`. The `/yoke-create` skill should call sync at its tail.

Follow-ups:

- Wire `/yoke-create` to call `/yoke:sync-docs` at the end of its pipeline.
- Wire `/yoke-release` to call `/yoke:sync-docs --check` as a precondition.
- Decide later whether to add a parallel `pnpm docs:check` for CI (currently
  out of scope; the release gate is a Claude run).
