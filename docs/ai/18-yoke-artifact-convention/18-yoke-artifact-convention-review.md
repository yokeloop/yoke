# Code Review: 18-yoke-artifact-convention

## Summary

### Context and goal

Migrate every yoke artifact path to a single `.yoke/` root (`.yoke/ai/<slug>/`,
`.yoke/context.md`, `.yoke/adr/`, `.yoke/journal.md`) across 13 skills plus
`lib/pr-collect.sh`, README/CLAUDE, the per-skill `docs/*.md` catalog sources,
and the regenerated site MDX — per ADR 0004. This is the S1 spine the rest of
the 2.0 epic depends on.

### Key code areas for review

1. **`skills/grill-docs/SKILL.md` + `reference/CONTEXT-FORMAT.md`** — the glossary
   collapse: multi-context (`CONTEXT-MAP.md` + per-`src/<context>/`) retired in
   favour of a single `.yoke/context.md`. The only structural change in the set.
2. **`skills/review/SKILL.md:160`, `skills/plan/SKILL.md:211`, `skills/task/SKILL.md:197`**
   — the gitignore-probe simplification (now "is `.yoke/` ignored?").
3. **`.gitignore`** — narrowed from blanket `.yoke` to `.yoke/sync-docs-tmp/` +
   `.yoke/notify-pending.json`; everything else under `.yoke/` is tracked.
4. **`lib/pr-collect.sh`** — the only executable path; `/pr` artifact discovery.
5. **`docs/<skill>.md` + `site/src/content/docs/skills/*.mdx`** — catalog sources
   feed `/sync-docs`; both migrated so the regenerated catalog is consistent.

### Complex decisions

1. **Glossary collapse** (`skills/grill-docs/reference/CONTEXT-FORMAT.md`) — dropping
   multi-context support per ADR 0004's literal single-file wording; confirmed
   coherent with no dangling `CONTEXT-MAP` references.
2. **Commit model** — edit sub-agents made file changes only; the orchestrator
   committed each task serially to avoid git index races across 11 parallel agents.

### Questions for the reviewer

1. Is dropping multi-context glossary support acceptable long-term, or should
   `.yoke/context/<name>.md` be reserved for a future multi-context need?

### Risks and impact

- **Breaking change (2.0):** existing repos on `docs/ai/` + root `CONTEXT.md` must
  migrate manually; no auto-migration (out of scope, per ADR 0004).
- **Cross-slice path contract:** the pipeline now passes `.yoke/ai/...` between
  skills; the deferred `do`/`bootstrap` slices (S3/S5) must adopt the same prefix
  or a half-migrated pipeline will mismatch.

### Tests and manual checks

**Auto-checks:** grep guard (zero in-scope `docs/ai`/`docs/adr`/`CONTEXT-MAP`),
`pnpm run format:check`, JSON/YAML validators, `/sync-docs --check` idempotence,
`git check-ignore` on `.yoke/ai` (tracked) vs scratch paths (ignored), `bash -n lib/pr-collect.sh`.

**Manual scenarios:**

1. Run `/yoke:prd` / `/yoke:plan` / `/yoke:task` → artifact lands at `.yoke/ai/<slug>/`.
2. Run `/yoke:grill-docs` → glossary at `.yoke/context.md`, ADR at `.yoke/adr/`.
3. Run `/pr` on a slug with `.yoke/ai/<slug>/` artifacts → discovered.

### Out of scope

- `do`, `journal`, `bootstrap` and their generated MDX — deferred to S3/S4/S5.
- Large historical design docs (`pi-*.md`, `skill-optimization-plan.md`) and
  transient `note.md` / `handoff-*.md`.
- ADR 0004's body prose (moved, not rewritten).

## Commits

| Hash      | Description                                                          |
| --------- | ------------------------------------------------------------------- |
| `4b2401d` | chore: move ADRs to .yoke/adr, narrow .gitignore                    |
| `e755e36` | refactor: collapse grill-docs glossary to .yoke/context.md          |
| `a8788bb` | refactor: point grill glossary refs at .yoke/context.md             |
| `9b51968` | refactor: migrate prd and issues artifacts to .yoke/ai              |
| `fb29350` | refactor: migrate review to .yoke/ai, drop docs/ai gitignore probe  |
| `07f965f` | refactor: migrate gca staging to .yoke/ai                           |
| `216844c` | refactor: migrate plan to .yoke/ai, switch gitignore probe to .yoke |
| `214bfeb` | refactor: migrate task to .yoke/ai, switch gitignore probe to .yoke |
| `a6311ea` | refactor: migrate explore and fix artifacts to .yoke/ai            |
| `84d2dc6` | refactor: report .yoke paths in help, note .yoke in handoff         |
| `6725938` | refactor: resolve pr-collect artifacts under .yoke/ai              |
| `69b6ad5` | docs: document .yoke convention in README and CLAUDE                |
| `1ff358b` | docs: regenerate skill catalog for .yoke convention                 |
| `5b5d69f` | docs: migrate per-skill docs and site pages to .yoke                |
| `4049432` | chore: normalize moved ADR formatting                               |
| `c69d7a1` | docs: add execution report                                          |
| `527960f` | fix: rename stale docs_ai label to yoke_ai                          |

## Changed Files

61 files changed, 604 insertions(+), 298 deletions(-) over the `#18` range. Highlights:
ADRs `0001`–`0005` moved to `.yoke/adr/`; 13 skills + `lib/pr-collect.sh` + README/CLAUDE +
10 `docs/*.md` + 14 site MDX migrated; `.gitignore` narrowed.

## Issues Found

| Severity | Score | Category      | File:line                                   | Description                                              |
| -------- | ----- | ------------- | ------------------------------------------- | -------------------------------------------------------- |
| Minor    | 22    | documentation | `skills/fix/agents/fix-context-collector.md:49,114` | Stale `SLUG_SOURCE="docs_ai"` label survived the migration |
| Minor    | 15    | documentation | `site/src/content/docs/skills/do.mdx`, `bootstrap.mdx` | Generated MDX still shows `docs/ai/` (deferred skills)    |

## Fixed Issues

| Issue                                  | Commit    | Description                                          |
| -------------------------------------- | --------- | --------------------------------------------------- |
| Stale `docs_ai` label (fix-context-collector.md) | `527960f` | Renamed `SLUG_SOURCE` value + spec to `yoke_ai`     |

## Skipped Issues

| Issue                                       | Reason                                                                                          |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `do.mdx`/`bootstrap.mdx` still on `docs/ai` | Generated from the deferred `do`/`bootstrap` skills (S3/S5). Editing the MDX directly would drift from source and fail the `/sync-docs --check` release gate; migrating the sources violates this slice's constraint. Defer to S3/S5. |

## Recommendations

- When S3 (`do`) and S5 (`bootstrap`) run, regenerate the catalog via `/sync-docs`
  so `do.mdx`/`bootstrap.mdx` pick up `.yoke/ai/` and the public docs become fully
  consistent.
- Consider an automated grep guard (CI or a `/yoke-validate` check) asserting no
  in-scope skill references `docs/ai`/`docs/adr`/root `CONTEXT.md`, to prevent
  regressions as the deferred slices land.
