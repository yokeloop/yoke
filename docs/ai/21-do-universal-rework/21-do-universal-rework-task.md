# S3 — `do` universal rework; deprecate `task`/`plan`

**Slug:** 21-do-universal-rework
**Ticket:** https://github.com/yokeloop/yoke/issues/21
**Complexity:** complex
**Type:** general

## Task

Rework the `do` skill into the universal execution tool that auto-detects its mode (inline / sub-agents / team), absorbs the "how/where" planning from `task`/`plan`, writes its plan artifact under `.yoke/ai/<slug>/`, and retire `task`/`plan` into a top-level `deprecated/` directory.

## Context

### Area architecture

`do` is today single-mode: it expects a pre-written `<slug>-plan.md` path and reads the `**Mode:**` header that `/plan` set (`skills/do/SKILL.md:27-34,59-64`). It runs a fixed 6-phase pipeline (Parse → Execute → Validate → Document → Finalize → Complete) dispatching agents under `skills/do/agents/`: `task-executor` (opus) → `task-reviewer` (sonnet, combined spec+quality) → `validator` (haiku) + `formatter` (haiku) in parallel → optional `doc-updater` → orchestrator writes the report. Status semantics + the review loop + parallel dispatch live in `skills/do/reference/status-protocol.md`.

The "how/where" planning to absorb lives in `plan`: `skills/plan/agents/plan-architect.md` (10-step: change map → patterns → design decisions → decomposition → file-intersection matrix → DAG → routing) and `skills/plan/reference/{routing-rules.md,plan-format.md}`. The plan-file contract `do` consumes is the `**Mode:**`/`**Parallel:**` header + `## Tasks` (each Files/Depends/Scope/What/How/Context/Verify, last task always Validation) + `## Execution` order. Investigation comes from `skills/task/agents/task-investigator.md` (entry points / patterns / tests / risks).

`do` is the **only** skill still on `docs/ai/` — every other skill already uses `.yoke/ai/`.

### Files to change

- `skills/do/SKILL.md` — the rework's core: input-shape mode router, absorbed planning, `.yoke/ai/` paths, drop `.gitignore` probe. Current `docs/ai/` at lines 29, 59, 68, 218, 227, 240, 260, 261; probe at 222, 261. Report-template appendix at 281-346.
- `skills/do/reference/report-format.md` — supplementary report template (drifts vs the inline one; add `team` to the `inline|sub-agents` mode field).
- **Create** `skills/do/reference/mode-inline.md`, `mode-sub-agents.md`, `mode-team.md` — per-mode flow detail (thin-router pattern, mirrors `status-protocol.md`).
- **Create** top-level `deprecated/` dir; **git mv** `skills/task/` → `deprecated/task/` and `skills/plan/` → `deprecated/plan/` (move each dir whole so internal relative refs survive).
- Absorb-from (read, fold the "how/where" logic into `do`): `skills/plan/agents/plan-architect.md`, `skills/plan/reference/{routing-rules.md,plan-format.md}`, `skills/task/agents/task-investigator.md`. The planning agents that `do` needs (`task-investigator`, `plan-architect`) move into `skills/do/agents/` so `do` can dispatch them after task/plan are deprecated.
- Catalog counts (hand-edit 18→16, drop plan/task from name lists): `skills/sync-docs/SKILL.md:36,71-74,206,233`, `skills/sync-docs/reference/sync-spec.md:43-45`.
- Delete orphan MDX: `site/src/content/docs/skills/task.mdx`, `plan.mdx` (sync-docs writes but never deletes orphans).
- Repoint handoffs into task/plan: `skills/issues/SKILL.md:104`, `skills/handoff/SKILL.md:17`, `skills/bootstrap/SKILL.md:341`, `skills/help/SKILL.md:19,31,41,167-171`, `skills/fix/SKILL.md:121,126,283`, `skills/gca/reference/commit-convention.md:64`.
- Hand-edit prose (outside sentinels): `README.md:43,129-133,285-303`, `CLAUDE.md` Implemented-skills block + do bullet.
- Re-run `/yoke:sync-docs` after edits (regenerates catalog from the now-16 skills).

### Patterns to reuse

- **Routing modes already sketched**: `skills/plan/reference/routing-rules.md:47-88` defines inline / sub-agents / agent-team with a fallback rule ("agent-team unavailable → degrade to sub-agents") — reuse the per-mode mechanics, but RE-ANCHOR detection on **input shape** (not the complexity matrix at lines 11-21).
- **Parallel-group / barrier dispatch + status loop**: `skills/do/reference/status-protocol.md` — reuse verbatim for sub-agents/team execution.
- **PRD sub-issue detection**: `skills/issues/reference/github-issues.md` documents the sub-issue conventions `/issues` uses — reuse its `gh` sub-issue reading for team-mode detection.
- **`.yoke/ai/` + commit-without-probe**: `task`/`plan`/`review` already write `.yoke/ai/` and only check whether `.yoke/` itself is ignored — copy that escape-hatch into `do`.
- **Thin-router → reference files**: `do` already offloads to `status-protocol.md`/`report-format.md`; extend the pattern with `reference/mode-*.md`.

### Tests

No automated test suite (markdown plugin). Validation = manual mode-trigger checks + `pnpm run format:check` + JSON/YAML validators + `/yoke:sync-docs --check`. Coverage gap: no guard that `do` no longer references `docs/ai/` or that the catalog dropped task/plan — the verification greps below substitute.

## Requirements

1. `do` auto-detects mode from **input shape** (per ADR 0005): plain chat task / no ticket → **inline**; a single issue URL or task/slug → **sub-agents**; a PRD ticket whose issue has sub-issues → **team**. Back-compat: an existing `*-plan.md` path → execute directly in **sub-agents** mode (skip planning).
2. **Inline mode**: plan briefly in chat, execute in the current session, **no pause**, and write **no plan file**.
3. **Sub-agents mode**: write the full `.yoke/ai/<slug>/<slug>-plan.md`, **pause for user confirmation**, then run the existing executor → reviewer → validator → formatter → report pipeline.
4. **Team mode**: detect a PRD-with-sub-issues input, write the full plan, pause for confirmation, then **dispatch via the sub-agents pipeline per sub-issue** (documented fallback). Do NOT wire real `TeamCreate` now (experimental/flag-gated); leave a clear extension point and the fallback note.
5. `do` produces its own "how/where" plan artifact under `.yoke/ai/<slug>/` (sub-agents/team modes) by absorbing `plan-architect`'s change-map/design/decomposition/DAG logic and `task-investigator`'s investigation; move those two agents into `skills/do/agents/`.
6. Migrate every `docs/ai/` in `skills/do/` to `.yoke/ai/`, and replace the two `.gitignore` probes with the single "is `.yoke/` ignored?" escape-hatch.
7. Keep `do`'s SKILL.md lean via a thin top-level router that branches to `reference/mode-inline.md`, `reference/mode-sub-agents.md`, `reference/mode-team.md`.
8. Move `skills/task/` → `deprecated/task/` and `skills/plan/` → `deprecated/plan/` (whole-dir `git mv`), out of auto-discovery; delete orphan `task.mdx`/`plan.mdx`.
9. Repoint every handoff/reference that pointed at `/yoke:task` or `/yoke:plan` to the `/yoke:do`-centric flow (issues, handoff, bootstrap, help, fix, commit-convention prose).
10. Update the hardcoded skill counts/lists (18→16, no plan/task) in sync-docs SKILL.md + sync-spec; update README/CLAUDE prose; reference/close #5; re-run `/yoke:sync-docs`.

## Constraints

- Keep `skills/do/agents/code-polisher.md` in place — only `fix` uses it (`fix/SKILL.md:18,180`); moving/removing it breaks `fix`.
- Preserve the `do/agents/` paths that `fix` and `review` reach into by `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/...` (`fix/SKILL.md:17-21,155-202`, `review/SKILL.md:18-19,135-136`). If agents are reorganized, keep those exact paths valid.
- Preserve the `$ARGUMENTS = SLUG` contract `/review` relies on (`review/SKILL.md:212` "Invocation from /do and /fix unchanged").
- Do NOT delete `task`/`plan` — move them to `deprecated/` (readable, un-discovered, reversible) per ADR 0005.
- Do NOT touch the sentinel-managed catalog rows in README/CLAUDE by hand — let `/yoke:sync-docs` regenerate them; hand-edit only prose outside the sentinels.
- Do NOT wire experimental `TeamCreate` dispatch — team mode falls back to sub-agents per sub-issue.
- Keep the confirmation pause as the safety net: a wrong auto-detect never triggers an unreviewed costly run (only inline runs without a pause, and only for small chat tasks).
- This is a breaking change (2.0.0): direct callers of `/yoke:task` / `/yoke:plan` lose them.

## Verification

- `grep -rn "docs/ai\|docs/adr" skills/do/` → no matches (do fully on `.yoke/ai/`).
- `grep -rn "gitignore" skills/do/SKILL.md` → references `.yoke/` only, no `docs/ai/` probe.
- `ls deprecated/` → `task/ plan/`; `ls skills/task skills/plan 2>&1` → absent; `ls skills/*/ | wc -l` → 16 skill dirs.
- `ls skills/do/agents/` → includes `task-investigator.md`, `plan-architect.md` (absorbed) and still `code-polisher.md`, `task-executor.md`, `task-reviewer.md`, `validator.md`, `formatter.md`, `doc-updater.md`.
- `ls skills/do/reference/` → includes `mode-inline.md`, `mode-sub-agents.md`, `mode-team.md`.
- `test ! -e site/src/content/docs/skills/task.mdx && test ! -e site/src/content/docs/skills/plan.mdx` → orphans removed.
- `grep -rn "/yoke:task\|/yoke:plan" skills/ README.md CLAUDE.md` → no live handoff references (only inside `deprecated/` or historical docs).
- `grep -rn "18 skills\|18 today\|, plan,\|, task," skills/sync-docs/` → counts/lists updated to 16 without plan/task.
- `/yoke:sync-docs --check` → no drift; catalog shows 16 skills, no `/yoke:plan` / `/yoke:task` rows.
- `pnpm run format:check` → clean; JSON/YAML validators → OK; `head -1 skills/*/SKILL.md` → all `---`.
- Manual: a plain chat task → inline (no pause, no file); a single issue URL → sub-agents (writes plan, pauses); a PRD issue with sub-issues → team (writes plan, pauses, dispatches per sub-issue via sub-agents); an existing `*-plan.md` path → executes directly.

## Materials

- [Issue #21 — S3 do universal rework](https://github.com/yokeloop/yoke/issues/21)
- [Issue #5 — /yoke:do V3 (agent-team)](https://github.com/yokeloop/yoke/issues/5) — absorbed; reference/close
- [Epic #17 — yoke 2.0](https://github.com/yokeloop/yoke/issues/17)
- `.yoke/adr/0005-do-universal-orchestrator.md` — source-of-truth design
- `skills/plan/reference/routing-rules.md` — the 3-mode mechanics to re-anchor on input shape
- `skills/plan/reference/plan-format.md` — plan-file contract `do` consumes
- `skills/do/reference/status-protocol.md` — status loop + parallel dispatch to reuse
- `skills/issues/reference/github-issues.md` — PRD sub-issue conventions for team detection
