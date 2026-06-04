# Mode: team

The broadest input shape: a **PRD ticket that has GitHub sub-issues**. The router (`skills/do/SKILL.md`) delegates here when the input resolves to a PRD issue whose `sub_issues` list is non-empty.

You are the orchestrator. Team mode does not introduce a new execution engine — it **reuses the sub-agents pipeline (`reference/mode-sub-agents.md`) once per sub-issue** and aggregates the results. Talk to the user only once, at the confirmation gate.

**Flow:**

```
0. Detect    → read the PRD's sub_issues; empty → fall back to sub-agents mode
1. Plan      → write an aggregate <slug>-plan.md mapping each sub-issue → slice
2. Confirm   → AskUserQuestion: confirm / adjust / cancel  (the ONE pause)
3. Dispatch  → per sub-issue, run the sub-agents pipeline (Execute→Validate→report)
4. Aggregate → write a single <slug>-report.md across all sub-issues
```

Track every phase in TodoWrite. **Report Mode is `team`.**

**Status semantics, the review loop, and parallel dispatch live in `reference/status-protocol.md`. The per-sub-issue Execute/Validate/Document phases live in `reference/mode-sub-agents.md`. Read both before Phase 3; do not duplicate their rules here.**

---

## Phase 0 — Detect sub-issues

Resolve the input to a PRD issue number, then read its sub-issues via the REST API (the same approach `/issues` uses to link them — see `${CLAUDE_PLUGIN_ROOT}/skills/issues/reference/github-issues.md`, "Sub-issues"):

```bash
gh api "repos/{owner}/{repo}/issues/<n>/sub_issues" \
  --jq '[.[] | {number, title, state}]'
```

`gh` fills `{owner}`/`{repo}` from the current repo; `<n>` is the PRD issue number.

**No sub-issues (empty list, or the endpoint is unavailable on this repo plan):** this is a single issue, not a PRD. **Fall back to `reference/mode-sub-agents.md`** for the whole input and stop here — do not run the team pipeline.

**Sub-issues present:** derive `SLUG` and `TICKET_ID` for the PRD per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`. List the sub-issues **in dependency order** — read each sub-issue body (`gh issue view <number>`) for a `## Depends on` / `## Parent` reference or an explicit order; absent that, keep the order returned by the API. Record the ordered list as `SUB_ISSUES`.

**Transition:** sub-issues listed in dependency order → Phase 1.

---

## Phase 1 — Plan (aggregate)

Write one coordinating plan that maps **each sub-issue to its planned slice**, persisted at `.yoke/ai/<SLUG>/<SLUG>-plan.md`.

Build it per sub-issue, in dependency order. For each sub-issue, run the **Plan phase of `reference/mode-sub-agents.md`** (investigate via `agents/task-investigator.md`, then architect via `agents/plan-architect.md`) scoped to that sub-issue's body, and capture its slice: tasks, file-intersection matrix, recommended mode, and execution order. Reuse that machinery — do not re-derive it here.

Assemble the aggregate plan:

- `**Mode:**` `agent-team` and the PRD-level `**Parallel:**` field (whether independent sub-issues may run concurrently).
- `## Sub-issues` — one subsection per sub-issue, in dependency order: number, title, its mapped slice (the per-sub-issue task list + execution order from its architect pass), and `Depends on:` the sub-issue(s) that must land first.
- `## Execution` — the cross-sub-issue order: which sub-issues are independent (eligible to run back-to-back or in parallel) and which are gated by `Depends on`.
- `## Verification` — the PRD's acceptance criteria, unchanged.

Self-check the prose: active voice, imperative mood, concrete files and lines, no needless words.

Auto-commit the plan artifact with the escape-hatch — check: is `.yoke/` in `.gitignore`? If yes, tell the user and skip the commit. Otherwise `git add .yoke/ai/<SLUG>/<SLUG>-plan.md` and commit `TICKET docs(SLUG): add implementation plan` (NO colon after the ticket).

**Transition:** aggregate plan written → Phase 2.

---

## Phase 2 — Confirm (the safety pause)

The single confirmation gate. Present the aggregate plan, then pause **before any code change** — the safety net against a misdetected shape or a wrong dependency order.

Summarize for the user:

- PRD title and SLUG.
- The ordered sub-issue list with each one's mapped slice (task count, recommended mode) and its `Depends on`.
- The cross-sub-issue execution order.
- Any IMPLEMENTATION QUESTIONS raised by the per-sub-issue architect passes.

Ask via **AskUserQuestion**:

1. **Confirm and execute (Recommended)** — proceed with the plan as written.
2. **Adjust** — capture the user's changes (sub-issue order, scope, answers to open questions), update `.yoke/ai/<SLUG>/<SLUG>-plan.md`, re-commit the artifact, and re-present.
3. **Cancel** — stop. Leave the plan file in place; make no code changes.

**Do not skip this pause.** It is the only stop in the pipeline.

**Transition:** user confirms → Phase 3.

---

## Phase 3 — Dispatch (per sub-issue)

<!-- extension point: when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 is available, wire real TeamCreate (lead coordinator + per-sub-issue teammates + shared task list) here; until then, the loop below is the documented fallback. -->

**Current behavior is the documented fallback:** there is no real `TeamCreate` wiring yet. Iterate the sub-issues **sequentially, in dependency order, dispatching each independently** through the sub-agents pipeline. Each sub-issue is executed in full isolation — it receives only its own body and slice, not the whole PRD.

For each sub-issue in `SUB_ISSUES`, in dependency order:

```
1. Scope the run to this sub-issue: its number, title, body, and the slice
   (tasks + execution order) from the aggregate plan's ## Sub-issues subsection.

2. Run the Execute → Validate → (opt-in Document) → Finalize-report phases of
   reference/mode-sub-agents.md, scoped to this sub-issue:
   - Execute  → task-executor per task + review loop, one commit per task
                (see reference/status-protocol.md for statuses + review loop)
   - Validate → validator + formatter in parallel
   - Report   → collect this sub-issue's task statuses, commit hashes, concerns,
                and validation results for Phase 4 (do NOT write a separate
                per-sub-issue report file — the aggregate report in Phase 4 covers all)

3. Commits use the sub-issue's own TICKET_ID, not the PRD's, so each slice's
   history points at the issue it implements.

4. On BLOCKED within a sub-issue: per status-protocol.md, block only the dependent
   tasks inside that sub-issue and keep its independent tasks running.

5. If an entire sub-issue is BLOCKED, mark every sub-issue that Depends on it as
   SKIPPED, then continue with the independent sub-issues. Send:
   bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ALERT --skill do --title "Sub-issue blocked" --body "<sub-issue number, reason, count of skipped sub-issues>"

6. Mark the sub-issue in TodoWrite: [x]
```

Keep the run going: a single blocked sub-issue stops only the branch that depends on it.

**Transition:** all sub-issues executed (or BLOCKED/SKIPPED) → Phase 4.

---

## Phase 4 — Aggregate report

Write **one** report at `.yoke/ai/<SLUG>/<SLUG>-report.md` via the Write tool, summarizing every sub-issue's outcome. Use the **Report template** (the appendix in `skills/do/SKILL.md`) with **Report Mode `team`**.

Fill it from data the orchestrator already holds across all sub-issue runs:

- Per sub-issue: number, title, final status (DONE / DONE_WITH_CONCERNS / BLOCKED / SKIPPED), its task statuses, commit hashes, concerns text, block/skip reasons, and validation command results.
- A roll-up line: `<SLUG> done (X/Y sub-issues)` or `<SLUG> done with issues (X/Y sub-issues, K blocked)`.
- The full FILES_CHANGED set. Run `git log origin/main..HEAD --oneline` to collect commits across all sub-issues.

**Auto-commit the report with the escape-hatch:** Check: is `.yoke/` in `.gitignore`? If yes — tell the user and skip the commit. Otherwise `git add .yoke/ai/<SLUG>/<SLUG>-report.md` and commit `TICKET docs(SLUG): add execution report` (NO colon after the ticket).

Send the STAGE_COMPLETE notification:
`bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill do --title "<SLUG> done (X/Y sub-issues)" --body ".yoke/ai/$SLUG/$SLUG-report.md"`

Report the path to the aggregate report file.

---

## Rules

- **One pause only.** Phase 2 confirmation. Every other phase runs without stops.
- **Reuse, don't duplicate.** Per-sub-issue Execute/Validate/Document come from `reference/mode-sub-agents.md`; statuses and the review loop from `reference/status-protocol.md`.
- **Fallback now, TeamCreate later.** Phase 3 dispatches sub-issues sequentially and independently via sub-agents. The marked extension point is where real `TeamCreate` lands once `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is available.
- **Commits by sub-issue.** Each sub-issue's commits carry its own ticket ID, per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- **On BLOCKED, keep going.** Block only the sub-issues that depend on the blocked one.
- **All artifacts under `.yoke/ai/`.** The aggregate plan and the aggregate report both live in `.yoke/ai/<SLUG>/`. One report for the whole PRD, not one per sub-issue.
- **TodoWrite.** Mark each sub-issue immediately upon completion.
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
