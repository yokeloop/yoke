# Code Review: 15-public-docs-site

## Summary

### Context and goal

Stands up an Astro Starlight docs site under `site/` published at `yokeloop.github.io/yoke`, introduces a new shipped skill `/yoke:sync-docs` that regenerates the public skill catalog (per-skill MDX pages, the README table between sentinels, the CLAUDE.md bullet list between sentinels) from `skills/*/SKILL.md`, wires `/yoke-release` to a Phase 0 drift gate against that skill, and replaces the stale README/CLAUDE.md hand-edit steps at the tail of `/yoke-create` with a single sync invocation. Adds the GitHub Pages-from-Actions deploy workflow and lands ADRs 0001/0002.

### Key code areas for review

1. **`skills/sync-docs/SKILL.md`** — orchestrator contract: 5 phases (preflight → enumerate → render → sentinel check → write/diff), `--check` vs write mode, prettier normalisation rule.
2. **`skills/sync-docs/reference/sync-spec.md`** — invariants the renderer must hold (sentinel anchoring, side-channel rule, idempotence).
3. **`skills/sync-docs/reference/mdx-template.md`** — 7-section MDX template the renderer instantiates per skill.
4. **`.claude/skills/yoke-release/SKILL.md:100-106`** — new Phase 0f docs drift gate that halts the release on `--check` non-green.
5. **`.claude/skills/yoke-create/SKILL.md:321-377`** — Phase 6 collapsed to docs + sync + format; the old `### /<name>` hand-edit steps are removed.
6. **`.github/workflows/docs.yml`** — Pages-from-Actions deploy (`configure-pages` → `upload-pages-artifact` → `deploy-pages`); path-filtered build trigger.
7. **`site/astro.config.mjs`** — `site` + `base` + workflow-stage sidebar; sets the `/yoke/` URL space and the 5 sidebar groups.
8. **`site/src/content.config.ts`** — Astro 5 content collection wiring required for Starlight after the T11 fix.
9. **`README.md:50-73` and `CLAUDE.md:62-83`** — the sentinel-wrapped catalogs sync-docs owns end-to-end.
10. **`docs/adr/0001..0002`** — ADR pair documenting the framework choice and the sync-docs decision.

### Complex decisions

1. **Sentinel matching must be line-anchored** (`sync-spec.md:13`) — the sync-docs catalog row literally mentions the marker strings, so a naive count returns 2. Anchored matching is essential for the skill's own row to not trip its sentinel check.
2. **Prettier in the pipeline** (`SKILL.md:155-158, 176-181`) — both write and check paths run `prettier --write` so the round-trip target equals what husky's lint-staged would re-introduce on commit. Without it the next commit always re-flags drift.
3. **Pages-from-Actions instead of gh-pages branch** (`docs.yml`, ADR 0001 Amendment) — the workflow diverges from ADR 0001's original Decision section; ADR 0001 now carries an Amendment that supersedes that bullet.
4. **`/yoke-release` Agent 3 deletion** (`yoke-release/SKILL.md:112,193`) — Phase 1 now runs 3 agents numbered 1, 2, 4 (no renumber). The orchestration text and the wait line both agree on "3 agents".
5. **Hardcoded `/yoke/` base in landing/internal links** — `index.mdx:10,14` embed the base manually because Starlight does not auto-prefix author-written links the way it does sidebar entries.

### Questions for the reviewer

1. The GH repo setting **Settings → Pages → Source = GitHub Actions** must be flipped manually before the first deploy succeeds. Is that being tracked separately, or do we want a CHANGELOG entry / runbook note added to this PR?
2. The 18 generated MDX pages add ~5000 lines to the repo. Generated artifacts are visible in `site/src/content/docs/skills/` because Astro reads them from there. Acceptable, or should we move to a build-time generator that emits into `dist/` only? (Out of scope for this PR per the PRD; recording for future.)
3. ADR 0002 still says "single source of truth via `/yoke:sync-docs`". The skill keeps `docs/<name>.md` as a fallback source for the page summary; SKILL.md remains canonical for the catalog. The ADR wording does not surface that two-layer fallback. Worth a small clarification follow-up?

### Risks and impact

- `pnpm install --frozen-lockfile` in CI will fail if anyone updates `site/package.json` without re-running `pnpm install` locally. Standard, but worth flagging given how rarely the docs deps change.
- The `.yoke/sync-docs-tmp/` workspace is gitignored as `.yoke`; if someone ever names a real artifact `.yoke-something`, the pattern still excludes it. Fine for now.
- One-time GH repo setting (Settings → Pages → Source = GitHub Actions) is documented only in `docs.yml` and the report. First deploy after merge will silently no-op until it's flipped.
- The fix to `/yoke-release` is a behavior change on a shipped skill — release consumers should be told (CHANGELOG) that the gate now exists.

### Tests and manual checks

**Auto-tests:**

- `pnpm --filter site build` — already verified green (23 pages, 22 indexed).
- `pnpm run format:check` — verified green after fixes.
- Round-trip idempotence: `/yoke:sync-docs` twice in a row → second pass produces empty diff. Verified post-prettier fix.

**Manual scenarios:**

1. Flip Pages → GitHub Actions in repo settings → push to `main` → workflow runs → site loads at `https://yokeloop.github.io/yoke/` with sidebar, Pagefind search box, and at least the `/yoke:plan` page rendered.
2. Hand-edit one row of the README catalog table inside the sentinels → run `/yoke:sync-docs --check` → exits non-green and names `README.md`.
3. Remove the closing `<!-- yoke:skills:end -->` from `CLAUDE.md` → run `/yoke:sync-docs` (write) → refuses to write, names `CLAUDE.md`.
4. Run `/yoke-release` against a clean main → proceeds past Phase 0. Hand-edit the README table to introduce drift → run `/yoke-release` again → halts at `0f. Docs drift gate` with a pointer to `README.md`.
5. Run `/yoke-create` end-to-end for a throwaway skill → on completion, README and CLAUDE.md contain the new entry inside the sentinels and `site/src/content/docs/skills/<name>.mdx` exists. The previous Phase 6b/6c hand-edits leave no residue.

### Out of scope

- `pnpm docs:check` parallel CI helper (explicitly excluded by the task; only `/yoke:sync-docs --check` gates drift).
- i18n / non-English content.
- Custom Starlight theme; uses defaults.
- Tests for the renderer itself (no test infra exists in the repo).
- A build-time generator that emits MDX into `dist/` only (would avoid checking generated content into source; deferred).

## Commits

| Hash      | Description                                                                       |
| --------- | --------------------------------------------------------------------------------- |
| `9d5f6e5` | docs: add task definition                                                          |
| `b795c30` | docs: add implementation plan                                                      |
| `41c13ca` | chore: document yoke-validate local skill (preflight)                              |
| `9c04ec2` | feat: scaffold pnpm workspace and site ignore rules (T01)                          |
| `4f72e7e` | feat: add yoke:skills sentinel markers (T05)                                       |
| `f96996e` | feat: add /yoke:sync-docs skill with write and check modes (T06)                   |
| `e64d9d1` | feat: add site/ package with astro and starlight (T02)                             |
| `8d15a73` | feat: gate yoke-release on /yoke:sync-docs --check (T07)                           |
| `773fa16` | feat: collapse yoke-create Phase 6 to sync-then-format (T08)                       |
| `29add2e` | docs: add docs/sync-docs.md long-form skill doc (T10)                              |
| `03eb6d1` | feat: configure astro starlight site at /yoke base (T03)                           |
| `c8ff30a` | feat: add splash landing and three generic pages (T04)                             |
| `ab3ddaf` | feat: add docs deploy workflow via actions/deploy-pages (T09)                      |
| `8ae0412` | feat: first sync — 18 skill MDX pages and regenerated catalogs (T11 initial)       |
| `d12fbc4` | fix: quote MDX descriptions and add content collections config (T11 fix #1)        |
| `d4e8a54` | docs: land ADRs 0001 and 0002 (preflight)                                          |
| `21a9071` | fix: pipe sync output through prettier for round-trip idempotence (T11 fix #2)     |
| `2532097` | docs: add execution report                                                         |
| `d4274d4` | fix: fix 7 review issues (this review)                                             |
| `4839bc1` | docs: land PRD locally                                                             |

## Changed Files

| Slice                  | Files                                                                                 | +/-     |
| ---------------------- | ------------------------------------------------------------------------------------- | ------- |
| Workspace + ignores    | `pnpm-workspace.yaml`, `.gitignore`, `.prettierignore`                                | +8/-0   |
| Site package           | `site/package.json`, `pnpm-lock.yaml`                                                 | +4685/-0 |
| Astro config           | `site/astro.config.mjs`, `site/src/content.config.ts`                                 | +76/-0  |
| Landing + generic      | `site/src/content/docs/{index,what-is-yoke,install,concepts}.mdx`, `skills/.gitkeep`  | +158/-0 |
| Per-skill MDX (18)     | `site/src/content/docs/skills/*.mdx`                                                  | +4424/-0|
| sync-docs skill        | `skills/sync-docs/{SKILL.md,reference/mdx-template.md,reference/sync-spec.md}`        | +425/-0 |
| Long-form doc          | `docs/sync-docs.md`                                                                   | +66/-0  |
| Release-skill gate     | `.claude/skills/yoke-release/SKILL.md`                                                | +8/-32  |
| Create-skill collapse  | `.claude/skills/yoke-create/SKILL.md`                                                 | +4/-26  |
| GH Actions workflow    | `.github/workflows/docs.yml`                                                          | +75/-0  |
| Sentinel + catalog     | `README.md`, `CLAUDE.md`                                                              | +59/-186|
| ADRs                   | `docs/adr/0001-docs-site-on-astro-starlight.md`, `docs/adr/0002-sync-docs-skill.md`   | +179/-0 |
| Local skill (preflight)| `.claude/skills/yoke-validate/SKILL.md`                                               | +70/-0  |
| PRD + report           | `docs/ai/15-public-docs-site/*`, `docs/ai/public-docs-site/public-docs-site-prd.md`   | +1192/-0|

## Issues Found

| Severity     | Score | Category | File:line                                                       | Description |
| ------------ | ----- | -------- | --------------------------------------------------------------- | ----------- |
| Important    | 68    | bugs     | `.claude/skills/yoke-release/SKILL.md:193`                       | "Wait for all 4 agents to finish" inconsistent with Phase 1 declaring "Run 3 agents" |
| Important    | 62    | docs     | `docs/adr/0001-docs-site-on-astro-starlight.md:42,61`            | ADR marked Accepted but Decision section still states `gh-pages` branch deploy |
| Important    | 55    | docs     | `site/src/content/docs/concepts.mdx:32`                          | "yoke ships `/yoke:journal`" — wrong namespace; the command is `/journal` |
| Minor        | 40    | quality  | `skills/sync-docs/SKILL.md:36,71,205`, `docs/sync-docs.md:21,30` | Count inconsistency: "17 + sync-docs" vs "18 today" |
| Minor        | 32    | quality  | `skills/sync-docs/reference/mdx-template.md:14`                  | Template prescribes `import { Aside, Code }` that the renderer drops |
| Minor        | 28    | perf     | `.github/workflows/docs.yml:31-33`                               | `cancel-in-progress: false` queues stale builds; build job should cancel |
| Minor        | 22    | docs     | `skills/sync-docs/SKILL.md:246`                                  | "Phase 6c tail" — sync is now `6b` in yoke-create |

## Fixed Issues

| Issue                                                  | Commit    | Description                                                                                 |
| ------------------------------------------------------ | --------- | ------------------------------------------------------------------------------------------- |
| yoke-release wait line still said "all 4 agents"       | `d4274d4` | Changed to "Wait for all 3 agents to finish."                                                |
| ADR 0001 still said gh-pages branch deploy             | `d4274d4` | Status updated; added Amendment section documenting Pages-from-Actions supersession         |
| concepts.mdx claimed `/yoke:journal` is shipped        | `d4274d4` | Reworded: ships no plugin commands today; `/journal` is local-only at `.claude/commands/`   |
| Count "17 + sync-docs" vs "18 today"                   | `d4274d4` | Collapsed to "every directory under `skills/` (18 today)" in SKILL.md, sync-spec.md, docs   |
| Template prescribed an unused import line              | `d4274d4` | Import line removed from template; replaced with HTML comment explaining when to add one    |
| Workflow `cancel-in-progress: false` queued stale builds | `d4274d4` | Split into two `concurrency:` blocks — build cancels, deploy does not                       |
| "Phase 6c tail" but sync is now 6b                     | `d4274d4` | Updated Connections block to "Phase 6b tail"                                                |

## Skipped Issues

**All found issues were fixed.**

## Recommendations

- After merge, flip **Settings → Pages → Source = GitHub Actions** in the repo before pushing to `main` again, or the first deploy run will fail at the `actions/deploy-pages` step with a configuration error.
- Add a CHANGELOG entry noting the `/yoke-release` behavior change (Phase 0 docs drift gate now exists; releases halt on stale catalogs).
- Consider a small follow-up to clarify ADR 0002 around the two-layer source preference (`docs/<name>.md` then SKILL.md fallback) — currently only the SKILL.md and the report describe that.
- The 18 generated MDX pages are checked into source. A future iteration could move sync to a build-time generator that emits into `dist/` only; out of scope for this PR.
- Drift detection and marker safety hand-tests remain deferred — exercise them after the plugin is reloaded so `/yoke:sync-docs --check` is invocable.
