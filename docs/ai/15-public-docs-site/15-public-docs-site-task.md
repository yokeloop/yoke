# Public docs site

**Slug:** 15-public-docs-site
**Ticket:** https://github.com/yokeloop/yoke/issues/15
**Complexity:** complex
**Type:** general

## Task

Stand up `yokeloop.github.io/yoke` from an Astro Starlight scaffold under
`site/`, regenerate the public skill catalog from `skills/*/SKILL.md` through
a new shipped skill `/yoke:sync-docs`, gate `/yoke-release` on it, and refresh
docs at the tail of `/yoke-create`.

## Context

### Area architecture

The plugin ships through `.claude-plugin/plugin.json` and a marketplace entry;
Claude Code scans `skills/<name>/SKILL.md` and `commands/<name>.md`. Today,
skill content lives in four places that drift independently:

1. `skills/<name>/SKILL.md` — canonical instructions Claude loads.
2. `README.md` — public catalog as a 3-column markdown table inside an
   already-installed sentinel block (`README.md:48-70`).
3. `CLAUDE.md` — `## Implemented skills` bullet list (`CLAUDE.md:60-78`);
   sentinels are not present yet.
4. `docs/<name>.md` — per-skill long-form docs (one file per shipped skill).

The new pipeline introduces a fifth, machine-managed surface — per-skill MDX
pages under `site/src/content/docs/skills/<name>.mdx` — and binds all five
together with `/yoke:sync-docs`. The site builds with Astro Starlight, ships
through GitHub Actions using `actions/upload-pages-artifact` +
`actions/deploy-pages` (no `gh-pages` branch), and serves from
`https://yokeloop.github.io/yoke` with `base: '/yoke'`.

The shipped catalog stays restricted to the 17 skills under `skills/`; the
local-only `yoke-create` and `yoke-release` (under `.claude/skills/`) never
appear in `README.md`, the site, or the machine-managed CLAUDE.md block.
`CLAUDE.md`'s separate `## Local skills (development)` section stays
hand-edited.

### Files to change

**Scaffold (slice a):**

- `pnpm-workspace.yaml` (new): `packages: ['site']`.
- `site/package.json` (new): Starlight starter, `dev`/`build`/`preview`.
- `site/astro.config.mjs` (new): `site: 'https://yokeloop.github.io'`,
  `base: '/yoke'`, sidebar groups (Dev loop → Git → Analysis → Meta → Plugin
  dev), Pagefind on by default.
- `site/src/content/docs/index.mdx` (new): Starlight `splash` hero, install
  CTA, browse-skills CTA, feature cards by workflow stage.
- `site/src/content/docs/what-is-yoke.mdx`,
  `site/src/content/docs/install.mdx`,
  `site/src/content/docs/concepts.mdx` (new): generic pages.
- `site/src/content/docs/skills/.gitkeep` (new): per-skill MDX pages land
  here later via slice (b).
- `.gitignore`: append `site/dist/`, `site/node_modules/`, `site/.astro/`.
- `.prettierignore`: append the same three globs.
- `package.json`: confirm root scripts still target the repo root; lint-staged
  glob `*.{md,json}` already covers `site/**/*.{md,json}` written by sync —
  document the implication.

**Sync-docs skill (slice b):**

- `skills/sync-docs/SKILL.md` (new): orchestrator skill mirroring
  `.claude/skills/yoke-create/SKILL.md` structure (frontmatter, TodoWrite,
  phases, Rules). Two modes: write (default) and check (`--check` argument).
- `CLAUDE.md`: add `<!-- yoke:skills:start -->` and
  `<!-- yoke:skills:end -->` around the `## Implemented skills` block once,
  by hand, as part of this slice. Leave `## Local skills (development)`
  unmarked.

**Release-skill gate (slice c):**

- `.claude/skills/yoke-release/SKILL.md`: add a `0f. Docs drift gate` step at
  the end of Phase 0 (insert before `TodoWrite: mark "Preflight" as done.` at
  line 100) that runs `/yoke:sync-docs --check` and halts the release on
  drift. Remove Phase 1 Agent 3 (lines 164-192) — the sentinel block plus the
  check gate replaces it; its `### /<name>` heading scan no longer matches
  the README table format.

**Deploy workflow (slice d):**

- `.github/workflows/docs.yml` (new): trigger on `push` to `main` and
  `workflow_dispatch`. Uses `pnpm/action-setup`, `actions/setup-node`,
  `pnpm install`, `pnpm --filter site build`, `actions/upload-pages-artifact`
  (`path: site/dist`), `actions/deploy-pages`. Sets `permissions: pages:
  write, id-token: write`. Documents the one-time setting:
  Settings → Pages → Source = "GitHub Actions".

**Create-skill tail (slice e):**

- `.claude/skills/yoke-create/SKILL.md`: replace Phase 6b (lines 365-383)
  and Phase 6c (lines 383-394) with a single `6b. Sync docs` step that
  invokes `/yoke:sync-docs` after `6c. Format` (currently 6d, renumber).
  Both 6b and 6c today write README/CLAUDE.md in a `### /<name>` heading
  format that no longer exists in either file — keeping them would clobber
  the sentinel-wrapped table on every new skill.

### Patterns to reuse

- **Multi-skill enumeration**: `.claude/skills/yoke-release/SKILL.md:167-192`
  (Agent 3) already aggregates `skills/*/` filesystem state to reconcile
  README/CLAUDE.md — sync-docs uses the same enumeration before that agent is
  removed.
- **Aggregator skill prose tone**: `skills/help/SKILL.md:1-191` is the
  hand-maintained catalog whose style the splash page and per-skill MDX
  summaries should match.
- **Phase/TodoWrite orchestrator template**:
  `.claude/skills/yoke-create/SKILL.md` (frontmatter 1-9, TodoWrite block
  27-40, Phase 0 preflight at 44, Rules at 432-443).
- **Parallel-validation pattern** for `--check` mode:
  `.claude/skills/yoke-release/SKILL.md:104-217` runs Phase-1 agents in
  parallel; sync-docs `--check` mirrors this (one diff per target: per-skill
  MDX, README block, CLAUDE.md block).
- **Notify contract**: `lib/notify.sh` accepts
  `--type --skill --phase --slug --title --body`; STAGE_COMPLETE is the
  type for Phase Complete. Canonical examples:
  `skills/plan/SKILL.md:235`, `skills/bootstrap/SKILL.md:266`.
- **Commit convention**: `skills/gca/reference/commit-convention.md` —
  format `TICKET type(scope): subject`, no colon after the ticket.
- **Per-skill summary source preference**: the skill prefers
  `docs/<name>.md` when present (every shipped skill has one today), then
  falls back to `skills/<name>/SKILL.md` body extraction. The raw SKILL.md
  always appears verbatim inside the `<details>` block regardless of source.

### Tests

No unit tests for skills exist. Closest signals:

- `pnpm run format:check` (`package.json:21`) — prettier check against
  `**/*.{md,json}`.
- JSON manifest validation: `python3 -c "import json; json.load(open(...))"`
  (documented in `CLAUDE.md:39`); not wired into a script.
- Husky pre-commit (`.husky/pre-commit`): runs `npx lint-staged` →
  prettier on staged `*.{md,json}` (`package.json:28-30`).

Verification for this task is round-trip + manual QA per PRD lines 169-198.

## Requirements

1. `site/` exists with a working Astro Starlight scaffold:
   `pnpm --filter site dev` serves locally; `pnpm --filter site build`
   compiles `site/dist/` cleanly.
2. `astro.config.mjs` sets `site: 'https://yokeloop.github.io'`,
   `base: '/yoke'`, and a sidebar grouped as Dev loop → Git → Analysis →
   Meta → Plugin dev.
3. `site/src/content/docs/index.mdx` uses Starlight's `splash` template
   with a hero, an "Install" primary CTA, a "Browse skills" secondary CTA,
   and feature cards per workflow stage.
4. `site/src/content/docs/` includes three generic pages: "What is yoke?",
   "Install", "Concepts (skills vs. commands vs. agents)".
5. A new shipped skill at `skills/sync-docs/SKILL.md` runs in two modes:
   - **Write (default)**: regenerates one MDX per skill under
     `site/src/content/docs/skills/<name>.mdx`, the table between the
     existing `<!-- yoke:skills:start -->` ... `<!-- yoke:skills:end -->`
     markers in `README.md`, and the bullet list between the same markers
     in `CLAUDE.md`. The shipped catalog (README, site, CLAUDE.md's
     `## Implemented skills`) lists only the 17 skills under `skills/` —
     never `yoke-create` or `yoke-release`.
   - **Check (`--check`)**: diffs current files against what write would
     produce and exits non-green on drift, naming the affected files.
6. Each generated per-skill MDX page contains, top to bottom:
   1. Title `/yoke:<name>`.
   2. One-line description from the SKILL.md frontmatter.
   3. The trigger phrases pulled out of the description.
   4. A "Use it" example when derivable from the SKILL.md body
      (no `commands/<name>.md` extraction — that directory does not exist).
   5. Inputs / outputs / side effects (best-effort extraction).
   6. A `<details>` titled "Full instructions" with the raw SKILL.md body.
   7. Footer link "View source on GitHub" pointing at the canonical
      SKILL.md path on `main`.
7. The summary body (steps 4-5 above) sources from `docs/<name>.md` when
   present; otherwise the skill extracts from `skills/<name>/SKILL.md`. The
   verbatim SKILL.md inside the `<details>` block always wins.
8. `CLAUDE.md` gains `<!-- yoke:skills:start -->` and
   `<!-- yoke:skills:end -->` around its `## Implemented skills` block,
   added by hand in this task. The `## Local skills (development)` block
   stays hand-edited and unmarked.
9. `.claude/skills/yoke-release/SKILL.md` runs `/yoke:sync-docs --check` as
   the last step of Phase 0 (step `0f`); on drift the release halts and
   reports the affected file. Phase 1 Agent 3 is deleted.
10. `.github/workflows/docs.yml` builds the site on push to `main` and on
    `workflow_dispatch`, uploads `site/dist/` via
    `actions/upload-pages-artifact`, and publishes through
    `actions/deploy-pages`. Job permissions: `pages: write, id-token: write`.
11. `.claude/skills/yoke-create/SKILL.md` Phase 6 ends with a single sync
    invocation that runs `/yoke:sync-docs` after format. The stale Phase 6b
    (README hand-edit) and 6c (CLAUDE.md hand-edit) steps are removed.
12. `.gitignore` and `.prettierignore` each add `site/dist/`,
    `site/node_modules/`, `site/.astro/`.
13. `pnpm-workspace.yaml` exists with `packages: ['site']`.
14. The published site at `https://yokeloop.github.io/yoke` renders the
    landing page, the sidebar grouped by workflow stage, the search box
    (Pagefind), and at least the `/yoke:plan` page with all seven sections.

## Constraints

- Touch only the four sources sync-docs owns: per-skill MDX pages, the
  README table between sentinels, the CLAUDE.md bullet list between
  sentinels, and (in this task only) the one-time CLAUDE.md sentinel
  insertion. Every other byte of `README.md` and `CLAUDE.md` stays as-is.
- Refuse to write when sentinels are missing or unbalanced; report the
  affected file. Do not auto-insert sentinels — slice (b) adds the
  CLAUDE.md pair by hand, and from then on missing markers are an error.
- The shipped catalog lists only the 17 skills under `skills/`. Never
  publish `yoke-create` or `yoke-release` to the site or to README. Do
  not surface them in the CLAUDE.md `## Implemented skills` block.
- Do not place any file named `SKILL.md` inside `site/`. The plugin
  scanner walks `skills/<x>/SKILL.md` and `commands/<x>.md` — staying out
  of those names keeps the site invisible to it.
- The PRD's "GitHub Pages with `gh-pages` branch" wording (User Story 12,
  ADR 0001 Decision bullet 2) is superseded: this task uses Pages-from-
  Actions, so no `gh-pages` branch is created. Note this divergence in
  the implementation PR so ADR 0001 can be amended.
- Do not add a `pnpm docs:check` script (explicitly out of scope per the
  PRD); the only entry point to drift detection is
  `/yoke:sync-docs --check`.
- Site language: English only. Do not introduce i18n configuration.
- Do not delete `docs/<name>.md` files — sync-docs reads them as the
  summary source.
- Do not commit anything inside `site/dist/` or `site/.astro/`.

## Verification

- `pnpm install` from the repo root → resolves the new `site/` workspace
  without errors.
- `pnpm --filter site build` → exits 0; produces `site/dist/index.html`
  and `site/dist/skills/<name>/index.html` for every shipped skill.
- `pnpm --filter site dev` → serves at `http://localhost:4321/yoke/`;
  landing page loads with the hero, both CTAs, and the workflow-stage
  feature cards.
- Run `/yoke:sync-docs` twice in a row; the second run produces an empty
  diff (`git diff --stat` shows zero changes) — round-trip idempotence.
- Hand-edit one row of the table in `README.md` between the sentinels,
  then run `/yoke:sync-docs --check` → exits non-green and names
  `README.md` — drift detection.
- Remove the closing sentinel from `CLAUDE.md` and run `/yoke:sync-docs`
  (write mode) → refuses to write, names `CLAUDE.md` — marker safety.
- Run `/yoke-release` against a clean main; the release proceeds past
  Phase 0. Hand-edit the README table to introduce drift, run
  `/yoke-release` again → halts at the `0f. Docs drift gate` step with a
  pointer to `README.md`.
- Run `/yoke-create` end-to-end for a throwaway skill; on completion,
  `README.md` and `CLAUDE.md` contain the new entry inside the sentinels
  and `site/src/content/docs/skills/<name>.mdx` exists. The previous
  Phase 6b/6c hand-edits leave no residue.
- Push to `main`; the `docs.yml` workflow runs to success; visiting
  `https://yokeloop.github.io/yoke` shows the sidebar grouped by
  workflow stage, the Pagefind search box, and at least the
  `/yoke:plan` page rendered with all seven sections.
- `git ls-remote --heads origin gh-pages` returns empty — Pages-from-
  Actions does not create a `gh-pages` branch.
- `pnpm run format:check` exits 0 after the change.

## Materials

- [PRD #15 — Public docs site](https://github.com/yokeloop/yoke/issues/15)
- `docs/ai/public-docs-site/public-docs-site-prd.md`
- `docs/adr/0001-docs-site-on-astro-starlight.md`
- `docs/adr/0002-sync-docs-skill.md`
- `README.md:48-70` (existing sentinel block, table format)
- `CLAUDE.md:60-78` (`## Implemented skills` block, sentinels to add)
- `.claude/skills/yoke-release/SKILL.md:99-192` (Phase 0 tail and Phase 1
  Agent 3 to amend)
- `.claude/skills/yoke-create/SKILL.md:321-403` (Phase 6/7 to amend)
- `skills/help/SKILL.md` (catalog prose tone)
- `lib/notify.sh` (Phase Complete notification contract)
- `skills/gca/reference/commit-convention.md` (commit format)
- [Starlight docs](https://starlight.astro.build/) (framework reference)
- [`actions/deploy-pages`](https://github.com/actions/deploy-pages)
- [Pagefind](https://pagefind.app/) (Starlight default search)
