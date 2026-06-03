# Report: 18-yoke-artifact-convention

**Plan:** docs/ai/18-yoke-artifact-convention/18-yoke-artifact-convention-plan.md
**Mode:** sub-agents
**Status:** ✅ complete

## Tasks

| #   | Task                                          | Status  | Commit    | Concerns |
| --- | --------------------------------------------- | ------- | --------- | -------- |
| 1   | ADR move + `.gitignore` narrow + sync-spec    | ✅ DONE | `4b2401d` | —        |
| 2   | grill-docs glossary collapse → `.yoke/`       | ✅ DONE | `e755e36` | —        |
| 3   | grill prose → `.yoke/context.md`              | ✅ DONE | `a8788bb` | —        |
| 4   | prd + issues → `.yoke/ai`                     | ✅ DONE | `9b51968` | —        |
| 5   | review → `.yoke/ai` + probe simplified        | ✅ DONE | `fb29350` | —        |
| 6   | gca staging → `.yoke/ai`                      | ✅ DONE | `07f965f` | —        |
| 7   | plan → `.yoke/ai` + probe simplified          | ✅ DONE | `216844c` | —        |
| 8   | task → `.yoke/ai` + probe simplified          | ✅ DONE | `214bfeb` | —        |
| 9   | explore + fix → `.yoke/ai`                    | ✅ DONE | `a6311ea` | —        |
| 10  | help prose + handoff note                     | ✅ DONE | `84d2dc6` | —        |
| 11  | lib/pr-collect.sh → `.yoke/ai`               | ✅ DONE | `6725938` | —        |
| 12  | README + CLAUDE convention doc                | ✅ DONE | `69b6ad5` | —        |
| 13  | `/sync-docs` regenerate catalog + MDX         | ✅ DONE | `1ff358b` | —        |
| 14  | Validation                                    | ✅ DONE | —         | see below |
| 15  | per-skill `docs/*.md` + site pages (follow-up)| ✅ DONE | `5b5d69f` | see below |

## Post-implementation

| Step          | Status     | Commit    |
| ------------- | ---------- | --------- |
| Validate      | ✅ pass    | —         |
| Documentation | ⏭️ skipped | —         |
| Format        | ✅ done    | `4049432` |

## Concerns

### Task 14: Validation — two in-scope completeness gaps surfaced and fixed

Validation caught references the plan's investigation under-weighted:

1. **`docs/<name>.md` per-skill source files feed `/sync-docs`.** sync-spec Phase 3
   reads `docs/<name>.md` for each MDX page's `## Input`/example/Output. Those
   files (plan, review, task, prd, issues, gca, explore, fix, grill, grill-docs)
   still held `docs/ai/`, so the regenerated MDX reintroduced it. Fixed in Task 15.
2. **`site/src/content/docs/what-is-yoke.mdx`** (hand-written, not sync-managed)
   told users "artifacts live in `docs/ai/<slug>/`" — directly contradicting the
   new convention. Migrated in Task 15.

### Task 15: scope boundary

Migrated the per-skill `docs/*.md` for the **migrated** skills only, plus
`what-is-yoke.mdx`, then re-ran `/sync-docs` (regenerated `plan.mdx`, `review.mdx`).
Left untouched, by design: `docs/do.md`, `docs/bootstrap.md` (deferred slices);
the large historical design notes `docs/pi-adaptation.md`, `docs/pi-yoke-repo-plan.md`,
`docs/skill-optimization-plan.md`; and transient `docs/note.md` / `docs/handoff-*.md`.
These are not skill-catalog sources and fall outside the acceptance criteria.

### Pre-existing untracked artifacts now visible

Narrowing `.gitignore` un-hid pre-existing dogfood files (`.yoke/ai/yoke-2-global-refactor/`,
`.yoke/context.md`) and stray `docs/note.md` from earlier sessions. Left untouched —
they belong to other work, not this task.

## Validation

`grep -rn "docs/ai\|docs/adr\|CONTEXT-MAP" skills/ lib/ README.md CLAUDE.md docs/*.md site/src/content/` ✅ — zero hits except intentionally-deferred `do`/`bootstrap`
`pnpm run format:check` ✅ — all tracked files Prettier-clean
`python3 -c "import json; ... plugin.json; marketplace.json"` ✅ OK
`head -1 skills/*/SKILL.md` ✅ — all start with `---`
`/sync-docs --check` ✅ — no drift (idempotent)
`git check-ignore .yoke/ai` ✅ — not ignored (tracked by default)
`git check-ignore .yoke/sync-docs-tmp/x .yoke/notify-pending.json` ✅ — ignored
`ls .yoke/adr/` ✅ — 0001–0005 present; `docs/adr/` gone
`bash -n lib/pr-collect.sh` ✅ — no syntax errors
No test suite (markdown plugin repo) — N/A

## Changes summary

| File                                              | Action   | Description                                              |
| ------------------------------------------------- | -------- | ------------------------------------------------------- |
| `.yoke/adr/0001`–`0005`                           | moved    | ADRs relocated from `docs/adr/`; 0004 body preserved    |
| `.gitignore`                                      | modified | blanket `.yoke` → only `sync-docs-tmp/` + `notify-pending.json` |
| `skills/sync-docs/reference/sync-spec.md`         | modified | ignore assertion updated                                |
| `skills/grill-docs/**`, `skills/grill/SKILL.md`   | modified | glossary collapsed to single `.yoke/context.md`; ADRs → `.yoke/adr/` |
| `skills/{prd,issues,review,gca,plan,task,explore,fix,help,handoff}/**` | modified | artifacts → `.yoke/ai/`; gitignore probes simplified |
| `lib/pr-collect.sh`                               | modified | `/pr` artifact discovery → `.yoke/ai/`                  |
| `README.md`, `CLAUDE.md`                          | modified | `.yoke/` convention documented; catalog regenerated     |
| `docs/{explore,gca,issues,fix,grill,plan,grill-docs,prd,task,review}.md` | modified | per-skill catalog sources → `.yoke/` |
| `site/src/content/docs/skills/*.mdx`              | modified | regenerated catalog pages                               |
| `site/src/content/docs/what-is-yoke.mdx`          | modified | convention prose → `.yoke/ai/`                          |

## Commits

- `4b2401d` #18 chore: move ADRs to .yoke/adr, narrow .gitignore
- `e755e36` #18 refactor: collapse grill-docs glossary to .yoke/context.md, ADRs to .yoke/adr
- `a8788bb` #18 refactor: point grill glossary refs at .yoke/context.md
- `9b51968` #18 refactor: migrate prd and issues artifacts to .yoke/ai
- `fb29350` #18 refactor: migrate review to .yoke/ai, drop docs/ai gitignore probe
- `07f965f` #18 refactor: migrate gca staging to .yoke/ai
- `216844c` #18 refactor: migrate plan to .yoke/ai, switch gitignore probe to .yoke
- `214bfeb` #18 refactor: migrate task to .yoke/ai, switch gitignore probe to .yoke
- `a6311ea` #18 refactor: migrate explore and fix artifacts to .yoke/ai
- `84d2dc6` #18 refactor: report .yoke paths in help, note .yoke artifacts in handoff
- `6725938` #18 refactor: resolve pr-collect artifacts under .yoke/ai
- `69b6ad5` #18 docs: document .yoke convention in README and CLAUDE
- `1ff358b` #18 docs: regenerate skill catalog for .yoke convention
- `5b5d69f` #18 docs: migrate per-skill docs and site pages to .yoke
- `4049432` #18 chore: normalize moved ADR formatting
