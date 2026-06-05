# S3 — `do` universal rework; deprecate task/plan — implementation plan

**Task:** docs/ai/21-do-universal-rework/21-do-universal-rework-task.md
**Complexity:** complex
**Mode:** sub-agents
**Parallel:** false

## Design decisions

### DD-1: Router inline in `skills/do/SKILL.md`; mode bodies in `reference/`

**Decision:** SKILL.md keeps frontmatter (unchanged triggers), the Input contract, a small input-shape router, shared Rules, and the Report template. Each mode's pipeline moves to `reference/mode-{inline,sub-agents,team}.md`.
**Rationale:** Mirrors the existing thin-router→reference pattern (`skills/do/reference/status-protocol.md`, `report-format.md`); keeps the single `/yoke:do` trigger that `fix`/`review` handoffs call.
**Alternative:** Separate skills per mode — rejected; breaks the single `/yoke:do` trigger and the `fix`/`review` path contracts.

### DD-2: Mode detection by INPUT SHAPE (fixed), re-anchored from routing-rules

**Decision:** Router ladder, first match wins: (1) `*-plan.md` path → sub-agents, skip planning, read the file's `**Mode:**` header (back-compat; `agent-team` header → team); (2) single issue URL / `<slug>` / `*-task.md` → sub-agents; (3) PRD issue with GitHub sub-issues → team; (4) empty / plain chat → inline.
**Rationale:** ADR 0005 fixes input-shape as the contract; the old complexity×file-intersection table (`skills/plan/reference/routing-rules.md:11-21`) is repurposed inside mode-sub-agents.md as the parallel/sequential decision for the absorbed planner.
**Alternative:** Keep complexity-driven routing — rejected; contradicts ADR 0005.

### DD-3: Inline writes no artifact; sub-agents/team write the plan and pause

**Decision:** Inline = brief plan in chat, execute in-session, no pause, no file. Sub-agents/team produce `.yoke/ai/<slug>/<slug>-plan.md` via the absorbed `plan-architect` (+ `task-investigator` change map), then one confirmation pause before execution.
**Rationale:** The pause is the safety net (issue #21): a wrong auto-detect never triggers an unreviewed costly run; inline must stay frictionless.
**Alternative:** Pause in inline too — rejected by the task's R2.

### DD-4: Team mode = detect + fallback to sub-agents-per-sub-issue; no TeamCreate

**Decision:** mode-team.md detects the PRD/sub-issue shape, writes the plan, pauses, then runs the mode-sub-agents pipeline once per sub-issue. A marked `<!-- extension point: TeamCreate -->` records where real `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` wiring lands later.
**Rationale:** agent-team is experimental/flag-gated; the documented fallback keeps S3 shippable (task R4).
**Alternative:** Wire TeamCreate now — rejected by R4.

### DD-5: Migrate `skills/do/` to `.yoke/ai/`; collapse two `.gitignore` probes into one

**Decision:** Replace every `docs/ai/` in `skills/do/SKILL.md` (29,59,68,218,227,240,260,261) with `.yoke/ai/`; replace both probes (222,261) with the single task/plan escape-hatch ("Is `.yoke/` in `.gitignore`? If yes — tell the user and skip the commit").
**Rationale:** `do` is the only skill still on `docs/ai/`; all others already write `.yoke/ai/` without a per-location probe.
**Alternative:** Keep `docs/ai/` — rejected; leaves the migration incomplete.

### DD-6: Move planning agents with `git mv`, repoint internal references

**Decision:** `git mv skills/plan/agents/plan-architect.md` and `skills/task/agents/task-investigator.md` into `skills/do/agents/`; repoint their prose that names `/yoke:plan` / `/yoke:task`.
**Rationale:** `do` must dispatch them after task/plan are deprecated; no external path references their old location, so the move is safe (verified).
**Alternative:** Copy — rejected; ADR says move, and task/plan dirs go to `deprecated/`.

### DD-7: `deprecated/` is a top-level sibling of `skills/`, outside auto-discovery

**Decision:** `git mv skills/task deprecated/task`, `skills/plan deprecated/plan`. Auto-discovery and sync-docs enumerate `skills/*/` only, so `deprecated/` is invisible to discovery and the catalog automatically. The hardcoded "18" counts still need a hand-edit to "16".
**Rationale:** Readable, un-discovered, reversible via git history (ADR 0005).
**Alternative:** Delete task/plan — rejected by the task constraint.

### DD-8: Do not hand-edit sentinel catalog rows; let sync-docs regenerate

**Decision:** Touch only prose outside the `<!-- yoke:skills:start/end -->` sentinels; the `/yoke:sync-docs` barrier regenerates the catalog from the 16 surviving skills.
**Rationale:** Sentinel rows are generated; hand-edits get overwritten.
**Alternative:** Hand-edit rows — rejected; constraint.

## Tasks

### Task 1: Slim `do/SKILL.md` to a router; migrate `docs/ai`→`.yoke/ai`

- **Files:** `skills/do/SKILL.md` (edit)
- **Depends on:** none
- **Scope:** L
- **What:** Convert SKILL.md from a single 6-phase pipeline into a thin router that detects mode by input shape (DD-2 ladder) and reads the matching `reference/mode-*.md`. Keep frontmatter/`description` verbatim (triggers must not change), the Rules, and the Report template.
- **How:** Add a `## Router` section encoding the 4-step ladder. Replace the Pipeline (38-264) body with per-mode pointers. Migrate paths at 29,59,68,218,227,240,260,261 `docs/ai/`→`.yoke/ai/`. Replace both `Check … .gitignore` blocks (222,261) with the single `.yoke/` escape-hatch. Keep `$ARGUMENTS` accepting a path OR slug OR issue URL OR empty. Update report-template Mode field (287) to `inline | sub-agents | team`.
- **Context:** this plan DD-1/2/3/5; current `skills/do/SKILL.md` full; `skills/task/SKILL.md:195-209` + `skills/plan/SKILL.md:209-222` for the escape-hatch wording.
- **Verify:** `head -1 skills/do/SKILL.md` = `---`; `grep -c "docs/ai" skills/do/SKILL.md` = 0; frontmatter `description` unchanged vs HEAD.

### Task 2: Create `reference/mode-inline.md`

- **Files:** `skills/do/reference/mode-inline.md` (create)
- **Depends on:** Task 1
- **Scope:** S
- **What:** Inline mode body — brief plan in chat, execute in-session, NO pause, NO plan file (R2, DD-3).
- **How:** Document: build a short plan inline, execute steps in-session, run validation, print a brief summary. No `.yoke/ai/` write, no AskUserQuestion pause. Reference `status-protocol.md` only if it dispatches sub-agents (default: it does not).
- **Context:** this plan DD-1/DD-3; `skills/do/reference/status-protocol.md`.
- **Verify:** `test -f skills/do/reference/mode-inline.md`; states "no plan file" + "no pause"; `grep -c docs/ai` = 0.

### Task 3: Move planning agents into `do/agents/`; repoint internal refs

- **Files:** `git mv skills/plan/agents/plan-architect.md skills/do/agents/`; `git mv skills/task/agents/task-investigator.md skills/do/agents/`; edit both moved files
- **Depends on:** none
- **Scope:** M
- **What:** Relocate the two planning agents into `do/agents/` (R5); repoint prose naming `/yoke:plan` / `/yoke:task` to the do flow (DD-6).
- **How:** `git mv` both. In `task-investigator.md` change "belongs to `/yoke:plan`" → "belongs to `/yoke:do`'s Plan phase". In `plan-architect.md` keep the agent-team rule but note the sub-agents fallback (DD-4).
- **Context:** the two agents after move; this plan DD-4/DD-6.
- **Verify:** `test -f skills/do/agents/plan-architect.md && test -f skills/do/agents/task-investigator.md`; `grep -rn "skills/plan/agents\|skills/task/agents" skills/` → nothing.

### Task 4: Create `reference/mode-sub-agents.md` (absorbs Plan phase + pipeline)

- **Files:** `skills/do/reference/mode-sub-agents.md` (create)
- **Depends on:** Task 1, Task 3
- **Scope:** L
- **What:** Sub-agents mode — investigate (task-investigator) → plan (plan-architect) → write `.yoke/ai/<slug>/<slug>-plan.md` → pause for confirmation → executor→reviewer→validator+formatter→optional doc-updater→report (R3, R5).
- **How:** Lift the old 6-phase pipeline from current SKILL.md; prepend a Plan phase that dispatches `agents/task-investigator.md` then `agents/plan-architect.md` and writes the plan file (reuse plan/SKILL.md Phase 3 + `deprecated/plan/reference/plan-format.md`). Add one AskUserQuestion confirmation gate after the plan write, before execution. For `*-plan.md` input, skip investigate/plan/pause and read the `**Mode:**` header. Reuse `status-protocol.md` verbatim. All artifacts under `.yoke/ai/`.
- **Context:** old SKILL.md Phases 1-6 (Task 1 diff / git history); `deprecated/plan/SKILL.md:122-200`; `deprecated/plan/reference/plan-format.md`; `skills/do/reference/status-protocol.md`; this plan DD-2/DD-3.
- **Verify:** `test -f skills/do/reference/mode-sub-agents.md`; references `agents/plan-architect.md`, `agents/task-investigator.md`, `status-protocol.md`; exactly one confirmation pause; `grep -c docs/ai` = 0.

### Task 5: Create `reference/mode-team.md` (detect + fallback, extension point)

- **Files:** `skills/do/reference/mode-team.md` (create)
- **Depends on:** Task 4
- **Scope:** M
- **What:** Team mode — detect PRD-with-sub-issues, write plan, pause, dispatch the sub-agents pipeline per sub-issue (fallback; no real TeamCreate); leave a TeamCreate extension point (R4, DD-4).
- **How:** Detect via `gh api /repos/{owner}/{repo}/issues/<n>/sub_issues` (github-issues.md). For each sub-issue, run the mode-sub-agents pipeline. Add `<!-- extension point: wire CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS / TeamCreate here -->` plus a fallback note. One aggregate report under `.yoke/ai/<slug>/`.
- **Context:** `skills/issues/reference/github-issues.md`; `skills/do/reference/mode-sub-agents.md`; this plan DD-4.
- **Verify:** `test -f skills/do/reference/mode-team.md`; contains "extension point" + "sub_issues" + "fallback"; `grep -c docs/ai` = 0.

### Task 6: Add `team` to the report Mode field

- **Files:** `skills/do/reference/report-format.md:11` (edit)
- **Depends on:** Task 1
- **Scope:** S
- **What:** Extend the Report Mode field to `inline | sub-agents | team` (R4 reporting).
- **How:** Edit the `**Mode:**` line in `report-format.md:11`; confirm SKILL.md:287 (done in Task 1) matches.
- **Context:** `skills/do/reference/report-format.md`.
- **Verify:** `grep -n "team" skills/do/reference/report-format.md` matches the Mode line.

### Task 7: Deprecate task/plan — `git mv` dirs, delete orphan MDX + docs, fix counts

- **Files:** `git mv skills/task deprecated/task`, `skills/plan deprecated/plan`; `git mv docs/task.md deprecated/task/task-doc.md`, `docs/plan.md deprecated/plan/plan-doc.md`; `git rm site/src/content/docs/skills/task.mdx site/src/content/docs/skills/plan.mdx`; edit `skills/sync-docs/SKILL.md:36,71-74,206,233`, `skills/sync-docs/reference/sync-spec.md:43-45`
- **Depends on:** Task 3, Task 4, Task 5
- **Scope:** M
- **What:** Move both skill dirs out of auto-discovery into `deprecated/`, relocate their orphaned long-form docs, delete the two orphan MDX pages, and hand-edit the 18→16 counts + name lists dropping `plan`/`task` (R8, R10 counts).
- **How:** `mkdir -p deprecated`; `git mv skills/task deprecated/task && git mv skills/plan deprecated/plan`. `git mv docs/task.md docs/plan.md` into the deprecated dirs (so the stale long-form docs travel with them). `git rm` the two `.mdx`. In sync-docs/SKILL.md:36/206 "(18 today…)"→16; :71-74 list drop `plan, task`; :233 "all 18 skills"→16. In sync-spec.md:43-45 "18 skills" + list → 16 without `plan, task`.
- **Context:** `skills/sync-docs/SKILL.md:33-74,203-233`; `skills/sync-docs/reference/sync-spec.md:31-45`.
- **Verify:** `! test -e skills/task && ! test -e skills/plan && test -d deprecated/plan/agents`; `ls -d skills/*/ | wc -l` → 16; `! test -e site/src/content/docs/skills/task.mdx`; `grep -rn "18 " skills/sync-docs` → no catalog-count hits.

### Task 8: Repoint every `/yoke:task` and `/yoke:plan` handoff

- **Files:** `skills/issues/SKILL.md:104`; `skills/handoff/SKILL.md:17`; `skills/bootstrap/SKILL.md:341`; `skills/help/SKILL.md` (drop /task,/plan sections, rewrite Full cycle); `skills/fix/SKILL.md:121,126,283`; `skills/gca/reference/commit-convention.md:64`
- **Depends on:** none
- **Scope:** M
- **What:** Repoint every handoff/reference naming `/yoke:task` or `/yoke:plan` to the `/yoke:do`-centric flow (R9).
- **How:** issues:104 drop `/yoke:plan`; handoff:17 "unstarted → `/yoke:do`"; bootstrap:341 "Try `/yoke:do`…"; help: delete `### /task` + `### /plan` sections, fold intent into `### /do` (universal: chat→inline, ticket→sub-agents, PRD→team), rewrite Full cycle to a single `/yoke:do <ticket|description|nothing>`; fix:121,126,283 `/yoke:task`→`/yoke:do`; commit-convention.md:64 `(/task -> /plan -> /do -> /review)` → `(/do -> /review)`.
- **Context:** the six files at the cited lines; `skills/help/SKILL.md` flow sections.
- **Verify:** `grep -rn "/yoke:task\|/yoke:plan" skills/ | grep -v deprecated/` → nothing.

### Task 9: Update README/CLAUDE prose; close #5

- **Files:** `README.md:43,129-133,285-303`; `CLAUDE.md` (Implemented/Planned-skills prose outside sentinels)
- **Depends on:** Task 7, Task 8
- **Scope:** M
- **What:** Update human-written prose (outside sentinels) to the universal-`/do` flow; reference and close #5 (R10).
- **How:** README:43 `/yoke:task <ticket>`→`/yoke:do <ticket>`; :129-133 Core pipeline → single `/yoke:do`; :285-303 revdiff section point at the `/yoke:do` plan artifact. CLAUDE.md: edit prose around the (sentinel-generated) skill list and the "## Planned skills"/"Implemented skills" intro; drop task/plan from any hand-written list. `gh issue close 5 --comment "Delivered via S3 (#21) do-universal-rework; team mode = detect + sub-agents fallback, TeamCreate left as extension point."`
- **Context:** README.md 40-46,125-135,283-305; CLAUDE.md skills sections; this plan DD-8.
- **Verify:** `grep -n "/yoke:task\|/yoke:plan" README.md CLAUDE.md` → none outside historical/revdiff context; `grep -c "yoke:skills" README.md CLAUDE.md` unchanged (sentinels intact); `gh issue view 5 --json state` → CLOSED.

### Task 10: Regenerate catalog via `/yoke:sync-docs` (barrier)

- **Files:** `site/src/content/docs/skills/*.mdx` (regenerated, 16), README/CLAUDE sentinel blocks (regenerated)
- **Depends on:** Task 7, Task 8, Task 9
- **Scope:** S
- **What:** Run `/yoke:sync-docs` (write mode) to regenerate the per-skill MDX + README/CLAUDE catalog from the surviving 16 skills (R10).
- **How:** Invoke `/yoke:sync-docs`. It enumerates `skills/*/` (now 16), so task/plan rows drop automatically and `deprecated/` is ignored. Verify idempotence with `--check`.
- **Context:** `skills/sync-docs/SKILL.md`; this plan DD-7/DD-8.
- **Verify:** `/yoke:sync-docs --check` exits zero; catalog lists 16 rows, no `plan`/`task`.

### Task 11: Validation

- **Files:** —
- **Depends on:** all
- **Scope:** S
- **What:** Run full validation: manual mode-trigger checks, formatters, JSON/YAML validators, sync-docs drift gate.
- **Context:** —
- **Verify:** `head -1 skills/*/SKILL.md deprecated/*/SKILL.md` → all `---`; `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"` → OK; `pnpm run format:check` → clean; `/yoke:sync-docs --check` → no drift; `grep -rn "docs/ai" skills/do/` = 0; `grep -rn "skills/plan/agents\|skills/task/agents" skills/` = 0; `grep -rn "/yoke:task\|/yoke:plan" skills/ | grep -v deprecated` = 0; the five `do/agents/{task-executor,code-polisher,validator,doc-updater,formatter}.md` paths still referenced by fix/review resolve; `ls -d skills/*/ | wc -l` = 16; mode spot-checks (empty→inline, `*-plan.md`→sub-agents, PRD-with-sub-issues→team).

## Execution

- **Mode:** sub-agents
- **Parallel:** false
- **Reasoning:** 11 complex interdependent tasks on shared files (SKILL.md hub, catalog/sentinel barrier) where ordering, not throughput, dominates — run sequentially via sub-agents.
- **Order:**
  Sequential: Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 → Task 7 → Task 8 → Task 9 → Task 10 → Task 11
  Key barriers: T1-T6 (router + modes + agent moves) land BEFORE T7 (deprecation) — no capability gap; T10 (/yoke:sync-docs) is a late barrier after all SKILL/catalog edits; T11 (Validation) is last.

## Verification

- `grep -rn "docs/ai\|docs/adr" skills/do/` → no matches.
- `grep -rn "gitignore" skills/do/SKILL.md` → references `.yoke/` only.
- `ls deprecated/` → `task/ plan/`; `ls skills/task skills/plan 2>&1` → absent; `ls -d skills/*/ | wc -l` → 16.
- `ls skills/do/agents/` → includes `task-investigator.md`, `plan-architect.md`, and still `code-polisher.md`, `task-executor.md`, `task-reviewer.md`, `validator.md`, `formatter.md`, `doc-updater.md`.
- `ls skills/do/reference/` → includes `mode-inline.md`, `mode-sub-agents.md`, `mode-team.md`.
- `test ! -e site/src/content/docs/skills/task.mdx && test ! -e site/src/content/docs/skills/plan.mdx`.
- `grep -rn "/yoke:task\|/yoke:plan" skills/ README.md CLAUDE.md` → none outside `deprecated/`.
- `grep -rn "18 skills\|18 today\|, plan,\|, task," skills/sync-docs/` → updated to 16, no plan/task.
- `/yoke:sync-docs --check` → no drift; catalog shows 16, no `/yoke:plan` / `/yoke:task`.
- `pnpm run format:check` → clean; JSON/YAML validators → OK; `head -1 skills/*/SKILL.md` → all `---`.
- Manual: plain chat → inline (no pause/file); single issue URL → sub-agents (plan + pause); PRD issue with sub-issues → team (plan + pause + per-sub-issue dispatch); `*-plan.md` path → executes directly.

## Materials

- [Issue #21 — S3 do universal rework](https://github.com/yokeloop/yoke/issues/21)
- [Issue #5 — /yoke:do V3 (agent-team)](https://github.com/yokeloop/yoke/issues/5) — absorbed; close in Task 9
- [Epic #17 — yoke 2.0](https://github.com/yokeloop/yoke/issues/17)
- `.yoke/adr/0005-do-universal-orchestrator.md` — source-of-truth design
- `skills/plan/reference/routing-rules.md` — 3-mode mechanics to re-anchor on input shape
- `skills/plan/reference/plan-format.md` — plan-file contract `do` consumes
- `skills/do/reference/status-protocol.md` — status loop + parallel dispatch to reuse
- `skills/issues/reference/github-issues.md` — PRD sub-issue conventions for team detection
