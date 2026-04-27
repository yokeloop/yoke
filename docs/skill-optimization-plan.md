# Skill Optimization Plan — `/task`, `/plan`, `/do`, `/review`

**Goal:** cut wall-clock latency of the four core yoke skills by reducing sub-agent
dispatches, removing redundant phases, eliminating duplicate codebase exploration,
and inlining work that does not need a sub-agent.

**Current state (lines of orchestration only):**

| Skill     | SKILL.md | Phases | Sub-agents declared           | Agent files      | Reference files | Examples |
| --------- | -------- | ------ | ----------------------------- | ---------------- | --------------- | -------- |
| `/task`   | 286      | 6      | 2 + 1 copyeditor              | 2                | 3               | 2        |
| `/plan`   | 315      | 8      | 3 + 1 copyeditor              | 3                | 3               | 2        |
| `/do`     | 312      | 7      | 8 (per task: up to 7 calls)   | 7                | 2               | 0        |
| `/review` | 187      | 6      | 4 (issue-fixer fans out)      | 4 + 2 reused     | 1               | 0        |
| **Total** | 1100     | 27     | 17 unique agents              | 16 files         | 9               | 4        |

**Worst-case agent dispatch count for a 5-task plan running end-to-end
(`/task` → `/plan` → `/do` → `/review`):**

- `/task`: 2 explorers + 1 copyeditor = **3 dispatches**
- `/plan`: 1 explorer + 1 designer + 1 reviewer (×5 iters max) + 1 copyeditor = **3–8 dispatches**
- `/do`: per task up to 7 dispatches (executor + spec×3 + quality×3) × 5 tasks
  = **35** + polish + validator + doc-updater + formatter + report = **40 dispatches**
- `/review`: 1 reviewer + 1 issue-fixer (fans out N) + 1 validator + 1 formatter + 1 report-writer = **5+ dispatches**

**Total worst case: ~50 sub-agent calls** for one feature, with most of them
strictly sequential. This is the dominant source of latency.

---

## Root causes

### 1. Duplicate codebase exploration across skills (the #1 cost)

Three sequential agents do overlapping work:

- **`/task` → `task-explorer`** (`skills/task/agents/task-explorer.md:9-49`):
  "trace execution paths, map architectural layers, surface patterns and abstractions,
  document dependencies." Output includes "Essential file list."

- **`/task` → `task-architect`** (`skills/task/agents/task-architect.md:19-28`):
  "Codebase pattern analysis. Identify the stack, module boundaries, abstraction layers...
  Find similar features." Then writes a *full implementation plan with build order*
  — duplicating what `/plan` will do later.

- **`/plan` → `plan-explorer`** (`skills/plan/agents/plan-explorer.md:9-12`): explicitly
  says "task-explorer looks for *what exists and how it works*. You look for *how to
  implement it*." But it also re-runs Glob/Grep over the same area.

- **`/plan` → `plan-designer`** (`skills/plan/agents/plan-designer.md:39-65`): repeats
  "Codebase pattern analysis" (step 1), produces design decisions, file structure,
  decomposition, file intersections, DAG, routing — overlapping with task-architect.

For one feature we read the same code area **3-4 times** through different agent lenses.

### 2. Mandatory sequential review loops in `/do`

`skills/do/SKILL.md:122-133` describes the per-task Review Loop:
`task-executor` → `spec-reviewer` (max 3 iters) → `quality-reviewer` (max 3 iters).

For 5 tasks, this is 5 × (1 + up to 3 + up to 3) = **up to 35 sequential dispatches**
just for execute+review. Spec and quality review are orthogonal and could run as
**one combined reviewer in parallel** with the executor's commit step.

### 3. Phases dedicated to operations that are not phases

- `/task` Phase 5 — Commit Artifact (`skills/task/SKILL.md:233-251`): one `git add` + `git commit`.
- `/plan` Phase 7 — Commit Artifact (`skills/plan/SKILL.md:259-277`): same.
- `/do` Phase 6c — Commit Report Artifact (`skills/do/SKILL.md:252-265`): same.
- `/review` Phase 5c — Commit report artifact (`skills/review/SKILL.md:146-156`): same.
- `/plan` Phase 4 — Route (`skills/plan/SKILL.md:173-199`): a decision, not an action.

A phase boundary implies tracking, transition, and (in this codebase) a notification.
Trivial steps inflate the phase count and hide where the real work is.

### 4. Mandatory copy-edit sub-agents on a 1-2 page markdown

- `/task` Phase 4 step 4 (`skills/task/SKILL.md:223-228`): "Dispatch a subagent to copyedit the task file."
- `/plan` Phase 6 step 4 (`skills/plan/SKILL.md:247-252`): same for the plan file.

Both pass `reference/elements-of-style-rules.md` and ask for "active voice, concrete
language, drop needless words." The orchestrator (Opus or Sonnet) writes good prose
in the first place; a separate dispatch on already-written markdown is overhead with
near-zero quality delta.

### 5. `code-polisher` overlaps with `task-executor`'s self-review

`task-executor.md:128-156` already has a Self-Review section that checks:

- "No overbuilding (YAGNI)?"
- "Codebase patterns respected?"
- "Names precise: do they reflect intent, not mechanics?"
- "Found a problem — fix it before reporting."

Then `/do` Phase 3 launches `code-polisher` (`skills/do/agents/code-polisher.md:19-40`)
that checks the same axes: "Over-engineering, premature generalization, duplication,
complex conditions, redundant types, console.log, commented-out code, redundant
comments, unused imports."

This is a separate Opus dispatch + a separate commit per task that often introduces
churn. The work belongs inside the executor's self-review (or a project-level pre-commit
formatter).

### 6. `doc-updater` is risky default-on automation

`/do` Phase 5 (`skills/do/SKILL.md:196-220`) runs `doc-updater` after every plan.
The agent (`skills/do/agents/doc-updater.md:24-71`) tries to update README, CHANGELOG,
and JSDoc/docstrings on every public symbol it can detect. For most plugin work,
internal refactors, and bug fixes, this is unwanted noise that creates diffs the
human did not ask for.

### 7. `plan-reviewer` is a strict gate with up to 5 iterations

`/plan` Phase 5 (`skills/plan/SKILL.md:201-224`) dispatches `plan-reviewer`, allows up
to 5 iterations, and only then writes the file. The reviewer's checklist
(`skills/plan/agents/plan-reviewer.md:13-62`) overlaps heavily with `plan-designer`'s
own principles (atomicity, context isolation, decision rationale). One reviewer
enforces rules a competent designer already follows; iterations rarely pay off.

### 8. "Read every file from the essential file list" is a separate pass

`/task` Phase 2 step 2 (`skills/task/SKILL.md:86-87`) and `/plan` Phase 2
(`skills/plan/SKILL.md:90`): after the explorer returns, the orchestrator re-reads
each file the explorer cited. The explorer's findings already contain the relevant
excerpts. Reading them again multiplies tokens and round-trips.

### 9. Reference files loaded into context every run

- `reference/synthesize-guide.md` — 290 lines, read on every `/task`.
- `reference/frontend-guide.md` — 200+ lines, read on every UI `/task`.
- `reference/elements-of-style-rules.md` — read on every `/task` and every `/plan` (twice).
- `reference/plan-format.md` — read on every `/plan`.
- `reference/routing-rules.md` — 119 lines, read on every `/plan`.
- `examples/simple-task.md`, `examples/complex-task.md` — read on every `/task`.
- `examples/simple-plan.md`, `examples/complex-plan.md` — read on every `/plan`.

That is ~1500-2000 lines of reference + examples on every cold run. Most of the
content is style rules and templates that the orchestrator already follows. Only a
small fraction (the 5-dimension checklist, the plan format spec) is actually
load-bearing. The rest can be inlined or removed.

### 10. Notification spam

Every phase boundary emits a `notify.sh` call. Telegram notifications matter at
**ACTION_REQUIRED** (user input needed) and **STAGE_COMPLETE** (terminal). The
intermediate ones (e.g., `/task` Phase 3 "before AskUserQuestion") add noise.

### 11. revdiff loops baked into Complete phases

`/task` Phase 6 (`skills/task/SKILL.md:261-277`), `/plan` Phase 8, `/do` Phase 7,
`/review` Phase 6 — each ends with an `AskUserQuestion`-driven revdiff loop. For
users who do not use revdiff, this is an extra interactive prompt on every run.
Users who do can call `/revdiff` directly afterward.

### 12. Routing matrix targets a feature flag that is not on

`reference/routing-rules.md:74-88` describes the `agent-team` mode that requires
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and falls back to `sub-agents` if absent.
3 of the 9 rows in the decision table point to `agent-team`. In practice the
routing reduces to: 1-2 simple tasks → inline, 3+ tasks with parallel groups →
sub-agents. The 9-row matrix is over-engineered for the working subset.

---

## Per-skill optimization plan

Format: **Current → Target**, with the change list and the specific files
to update. Numbers in parentheses are estimated dispatch reductions.

### `/task` — current 6 phases / 3 dispatches → target 3 phases / 1 dispatch

**Changes:**

1. **Merge `task-explorer` + `task-architect` into a single `task-investigator`**
   that returns: entry points, patterns to reuse, tests in the area, integration
   risk zones, and a short "files needed by /plan" hint. Drop the architecture
   build-order output — that is `/plan`'s job.
   - Modify: `skills/task/agents/task-explorer.md` → rename + extend.
   - Delete: `skills/task/agents/task-architect.md`.
   - Modify: `skills/task/SKILL.md` Phase 2 → single dispatch.
   - **Saves:** 1 dispatch + 1 sequential wait per `/task`.

2. **Drop the copyedit sub-agent** in Phase 4. Inline the 5 style rules
   (`active voice`, `concrete language`, `drop filler`, `name files+lines`,
   `positive form`) directly into SKILL.md as a 5-bullet self-check.
   - Modify: `skills/task/SKILL.md` Phase 4 step 4 → remove.
   - Keep: `skills/task/reference/elements-of-style-rules.md` as documentation,
     but stop loading it.
   - **Saves:** 1 dispatch per `/task`.

3. **Drop "Read every file from the essential file list"** (Phase 2 step 2).
   The investigator's findings carry the excerpts.
   - Modify: `skills/task/SKILL.md:86-87`.

4. **Inline the synthesize 5 dimensions checklist** into SKILL.md (~30 lines)
   instead of reading 290 lines on every run.
   - Modify: `skills/task/SKILL.md` Phase 3 → embed checklist.
   - Demote: `skills/task/reference/synthesize-guide.md` to "see also" doc, not
     a mandatory read.

5. **Conditionally load `reference/frontend-guide.md`** only when investigator
   reports a frontend stack. Most non-UI tasks should never see it.

6. **Inline the artifact commit** into the Write phase (no separate Phase 5).
   - Modify: `skills/task/SKILL.md` Phase 4 last step → `git add && git commit`.
   - Delete: Phase 5.

7. **Make the revdiff loop in Complete optional** — single AskUserQuestion that
   merges the choice (`/yoke:plan` | `revdiff once` | `Finish`). Drop the
   re-loop after revdiff returns. If the user wants more revdiff passes, they
   invoke `/revdiff` manually.

8. **Drop the pre-AskUserQuestion notification** in Phase 3. Keep only the
   STAGE_COMPLETE notification at the end.

**Target shape:**

```
Phase 1 — Parse        # ticket fetch, slug, materials
Phase 2 — Investigate  # 1 task-investigator dispatch, no separate file read pass
Phase 3 — Write        # apply 5-dimension checklist inline, write file,
                       # ask clarifying Qs only if material, commit artifact inline
                       # (if docs/ai not gitignored)
[Complete loop]        # one AskUserQuestion: plan / revdiff / finish
```

### `/plan` — current 8 phases / 3-8 dispatches → target 3 phases / 1 dispatch

**Changes:**

1. **Merge `plan-explorer` + `plan-designer` into a single `plan-architect`**
   that produces: change map, decomposition, file intersection matrix, DAG,
   routing recommendation, design decisions. Skip the explorer step entirely
   — `/task`'s investigator already supplied the file list and patterns.
   - Modify: `skills/plan/agents/plan-explorer.md` → rename to `plan-architect`,
     fold designer's 7-step process in.
   - Delete: `skills/plan/agents/plan-designer.md`.
   - Modify: `skills/plan/SKILL.md` Phase 2+3 → single dispatch.
   - **Saves:** 1 dispatch + 1 sequential wait.

2. **Drop `plan-reviewer`.** Replace with a 6-bullet self-check inside
   plan-architect's output ("every requirement covered, no orphan tasks,
   atomic, depends_on valid, last task is Validation, every Verify is concrete").
   The architect runs the checklist before returning.
   - Delete: `skills/plan/agents/plan-reviewer.md`.
   - Modify: `skills/plan/SKILL.md` Phase 5 → remove. Move the consistency
     checks (currently Phase 4 lines 191-198) into the architect's self-review.
   - **Saves:** 1-5 dispatches.

3. **Drop the copyedit sub-agent** (Phase 6 step 4). Same reasoning as `/task`.
   - **Saves:** 1 dispatch.

4. **Inline routing decision** into the architect's output. Drop separate
   Phase 4 (Route).
   - Modify: `skills/plan/SKILL.md` → remove Phase 4.
   - Reduce: `skills/plan/reference/routing-rules.md` from 9-row matrix to
     3 simple rules embedded in SKILL.md:
     - 1-2 tasks, no shared files → `inline`
     - 3+ tasks with parallel groups → `sub-agents`
     - 2+ layers with strong coordination → `agent-team` (rare)

5. **Inline artifact commit** into Write phase (no Phase 7).

6. **Drop the pre-AskUserQuestion notification.** Keep only STAGE_COMPLETE.

7. **Drop the revdiff loop** from Complete; offer one merged choice.

8. **Stop loading examples on every run.** Inline a minimal plan template
   (~40 lines) into SKILL.md. Keep examples/ as docs.

**Target shape:**

```
Phase 1 — Load         # read task file, extract metadata
Phase 2 — Design       # 1 plan-architect dispatch (explorer+designer+reviewer
                       # responsibilities combined, self-review built in)
Phase 3 — Write        # ask material implementation Qs, write plan file with
                       # inline format, commit artifact inline
[Complete loop]        # one AskUserQuestion: do / revdiff / finish
```

### `/do` — current 7 phases / up to 40 dispatches → target 4 phases / ~12 dispatches for 5 tasks

**Changes:**

1. **Merge `spec-reviewer` + `quality-reviewer` into one `task-reviewer`**
   that does both passes in a single Sonnet dispatch (read code, check
   requirements, check quality). They share the same input (BASE_SHA, HEAD_SHA,
   requirements) and the same target (the implementer's diff).
   - Modify: `skills/do/agents/spec-reviewer.md` → rename to `task-reviewer`,
     fold quality-reviewer checks (file responsibility, code quality, tests,
     maintainability) in.
   - Delete: `skills/do/agents/quality-reviewer.md`.
   - Modify: `skills/do/reference/status-protocol.md` Review Loop section →
     one stage instead of two.
   - **Saves:** 5 dispatches per 5-task plan (one per task).

2. **Drop the `code-polisher` Phase 3 entirely.** Inline its checks into
   task-executor's self-review (most are already there).
   - Delete: `skills/do/agents/code-polisher.md`.
   - Modify: `skills/do/SKILL.md` → remove Phase 3.
   - Modify: `skills/do/agents/task-executor.md` Self-Review section → add
     the cleanup bullets (debug console.log, commented-out code, unused
     imports, redundant comments) that polisher currently checks.
   - **Saves:** 1 dispatch + 1 commit per `/do` run.

3. **Make `doc-updater` opt-in.** Default off. Only run when:
   - the plan explicitly contains a "Documentation" task, OR
   - the user passed `--update-docs` (or some equivalent flag), OR
   - the plan touches a public API surface flagged in CONSTRAINTS.
   - Modify: `skills/do/SKILL.md` Phase 5 → conditional, default skip.
   - **Saves:** 1 dispatch per `/do` run by default.

4. **Reduce review iterations from 3 to 2.** A second pass that fails almost
   never succeeds on a third. Record and continue.
   - Modify: `skills/do/reference/status-protocol.md:80, 93`.

5. **Inline the report-writer** into the orchestrator. The report is a
   template fill-in over data the orchestrator already holds.
   - Delete: `skills/do/agents/report-writer.md`.
   - Modify: `skills/do/SKILL.md` Phase 6b → orchestrator writes the report
     directly using `Write` tool.
   - Reduce: `skills/do/reference/report-format.md` to a minimal template
     embedded in SKILL.md.
   - **Saves:** 1 dispatch.

6. **Inline artifact commit** into Phase 6 (no separate 6c).

7. **Drop revdiff loop** from Phase 7; one merged AskUserQuestion.

8. **Combine validator + formatter dispatches if practical.** They run
   different commands and sometimes both need fixes. Keep them separate but
   schedule them in parallel (formatter does not depend on validator's
   result; if validator commits a fix, formatter runs on the new HEAD).
   - Modify: `skills/do/SKILL.md` Phase 6a + Phase 4 → dispatch in parallel
     where possible.

**Target shape:**

```
Phase 1 — Parse         # read plan, extract tasks, todos
Phase 2 — Execute       # for each task (or in parallel groups):
                        #   executor → task-reviewer (combined, max 2 iters)
                        # save changed files list
Phase 3 — Validate      # validator + formatter (parallel where possible)
                        # doc-updater only if explicitly enabled
Phase 4 — Complete      # write report inline, commit artifact, notify,
                        # one AskUserQuestion (review / revdiff / finish)
```

**Dispatch count for a 5-task plan (target):**

5 × (executor + task-reviewer) + 1 validator + 1 formatter = **12 dispatches**
vs current worst-case 40. Floor case: 5 × 2 + 2 = 12 vs 5 × 2 + 5 = 15 today.

### `/review` — current 6 phases / 3-5 dispatches → target 4 phases / 2-3 dispatches

**Changes:**

1. **Drop the `issue-fixer` orchestrator layer.** It only groups by file and
   dispatches `single-fix-agent` (`skills/review/agents/issue-fixer.md:21-31`).
   The `/review` orchestrator can do the grouping inline and dispatch
   `single-fix-agent` directly.
   - Delete: `skills/review/agents/issue-fixer.md`.
   - Modify: `skills/review/SKILL.md` Phase 4 → orchestrator groups + dispatches.
   - **Saves:** 1 dispatch.

2. **Inline the report-writer.** The orchestrator already has all the data
   (issues, fixed, skipped, commits).
   - Delete: `skills/review/agents/review-report-writer.md`.
   - Modify: `skills/review/SKILL.md` Phase 5a → orchestrator writes directly.
   - Reduce: `skills/review/reference/review-format.md` to a minimal embedded
     template.
   - **Saves:** 1 dispatch.

3. **Combine `Select` and `Complete` into a single AskUserQuestion** at the
   start when scope clarification is needed, with a "Skip fixes" branch that
   short-circuits to report-only.
   - Modify: `skills/review/SKILL.md` Phase 3 → keep as one ask.

4. **Inline artifact commit** in Finalize.

5. **Run validator + formatter in parallel after fixes** (same as `/do`).

**Target shape:**

```
Phase 1 — Parse           # SLUG, KNOWN_ISSUES from prior reports
Phase 2 — Analyze         # code-reviewer dispatch
Phase 3 — Fix             # AskUserQuestion (scope) → group issues by file →
                          # dispatch single-fix-agents in parallel where safe →
                          # validator + formatter in parallel
Phase 4 — Complete        # write report inline, post PR comments if PR exists,
                          # commit, notify, AskUserQuestion (gp / pr / finish)
```

---

## Cross-cutting changes

### A. Notification policy

Keep notifications only at:

- **ACTION_REQUIRED** — orchestrator is about to ask the user via `AskUserQuestion`.
- **STAGE_COMPLETE** — terminal phase of a skill.
- **ALERT** — `BLOCKED` task in `/do`.

Drop the per-phase notifications currently scattered through the SKILL.md files.

### B. Reference file diet

| File                                              | Action                                                       |
| ------------------------------------------------- | ------------------------------------------------------------ |
| `skills/task/reference/synthesize-guide.md`       | Inline the 5-dimension checklist into SKILL.md; demote file. |
| `skills/task/reference/frontend-guide.md`         | Load conditionally only on frontend stack.                   |
| `skills/task/reference/elements-of-style-rules.md`| Inline a 5-bullet checklist into SKILL.md; stop loading.     |
| `skills/plan/reference/routing-rules.md`          | Replace with 3 inline rules.                                 |
| `skills/plan/reference/plan-format.md`            | Inline minimal template into SKILL.md.                       |
| `skills/plan/reference/elements-of-style-rules.md`| Same as task — inline checklist.                             |
| `skills/do/reference/status-protocol.md`          | Keep — it is genuine protocol. Trim review iterations to 2.  |
| `skills/do/reference/report-format.md`            | Inline minimal template into SKILL.md.                       |
| `skills/review/reference/review-format.md`        | Inline minimal template into SKILL.md.                       |
| `skills/task/examples/*.md`                       | Keep as documentation, stop preloading.                      |
| `skills/plan/examples/*.md`                       | Keep as documentation, stop preloading.                      |

### C. Auto-commit pattern

Adopt one rule across all four skills: **the writing phase commits its own artifact.**
No separate "Commit Artifact" phase. The check `is docs/ai/ in .gitignore?` happens
once inside the same phase.

### D. Read-the-files step

In `/task` and `/plan`, drop the "read every file from the essential list" step.
Trust the explorer/architect's excerpts. If the orchestrator needs a specific file
for the writing phase, it reads on demand — not as a bulk pre-read.

### E. revdiff loop

Replace the multi-pass loop with a single optional invocation. The user can call
`/revdiff` manually for additional passes. This applies to all four skills.

### F. Validation via plugin-dev practices

After implementing the changes, validate using:

1. **`yoke-create` skill's quality validator**: run it on each modified SKILL.md
   to confirm the YAML frontmatter is valid, the skill is invocable, and the
   description still maps to the trigger phrases.
2. **Plugin loading test**: `claude --plugin-dir .` to confirm the plugin still
   loads and the slash commands resolve.
3. **End-to-end smoke test**: pick a small ticket, run `/task` → `/plan` → `/do`
   → `/review`, measure wall-clock against the current baseline.

---

## Implementation phases

**Shipping policy:** all six phases land in **one PR** on a single branch. Phases
define **execution order and commit boundaries** inside that PR — not separate PRs.
Each phase ends with one or more commits; the final commit opens the PR. Versioning
in `plugin.json` and `marketplace.json` is **not bumped** during this work; the user
will release manually via `/yoke-release` after the PR merges.

The order is chosen so each phase is reviewable as a discrete commit group, earlier
phases lower the risk surface for the later ones, and a baseline measurement after
each phase shows incremental impact. If a phase regresses, revert that phase's
commits without losing the rest.

### Phase 1 — Quick wins (commits within the single PR)

Risk: very low. No agent merges. No behavior change.

1. Drop the copyedit sub-agent from `/task` and `/plan`. Inline 5-bullet style
   checklist.
2. Inline auto-commit into the writing phase. Remove "Commit Artifact" phases
   from all four skills.
3. Drop intermediate notifications. Keep only ACTION_REQUIRED and STAGE_COMPLETE.
4. Drop "read every essential file" step in `/task` and `/plan`.
5. Stop loading examples/ for tone calibration. Keep them as docs.

**Expected impact:** ~10-15% wall-clock reduction. ~3 fewer dispatches per full run.

### Phase 2 — Reference file diet (commits within the single PR)

Risk: low. Style and template inlining; no logic change.

1. Inline the 5-dimension checklist into `/task` SKILL.md.
2. Inline the plan format template into `/plan` SKILL.md.
3. Inline the report format template into `/do` and `/review` SKILL.md.
4. Replace `routing-rules.md` 9-row matrix with 3 inline rules.
5. Make `frontend-guide.md` conditional.

**Expected impact:** smaller cold-start context; cache stays warmer; fewer file reads.

### Phase 3 — Merge agents (commits within the single PR)

Risk: medium. Validate with smoke tests after each merge.

1. Merge `task-explorer` + `task-architect` → `task-investigator`.
2. Merge `plan-explorer` + `plan-designer` → `plan-architect` (also folds in
   `plan-reviewer` checks as self-review).
3. Merge `spec-reviewer` + `quality-reviewer` → `task-reviewer`.

**Expected impact:** ~3 fewer dispatches per `/task`+`/plan` run. ~5 fewer per
5-task `/do` run. Plus elimination of sequential waits between merged pairs.

### Phase 4 — Inline single-purpose agents (commits within the single PR)

Risk: low. The targets already use Haiku and contain no model-dependent reasoning.

1. Inline `report-writer` into `/do`'s Complete phase.
2. Inline `review-report-writer` into `/review`'s Finalize phase.
3. Drop `issue-fixer` orchestrator layer in `/review`; dispatch `single-fix-agent`
   directly from the orchestrator.

**Expected impact:** 3 fewer dispatches per full run.

### Phase 5 — Drop optional pipeline (commits within the single PR)

Risk: medium. Behavior change visible to users.

1. Drop `code-polisher` Phase 3 in `/do`. Add cleanup checks to `task-executor`
   self-review.
2. Make `doc-updater` opt-in. Default off.
3. Reduce review iterations from 3 to 2 in `status-protocol.md`.
4. Replace revdiff loops with one-shot offers in Complete phases.

**Expected impact:** another ~2 dispatches per `/do` run; faster Complete phases
across the board.

### Phase 6 — Parallelize where possible (commits within the single PR)

Risk: medium. Requires care around git state.

1. Run validator + formatter in parallel in `/do` Phase 3 and `/review` Phase 4.
2. In `/do` Phase 2, ensure parallel groups from the plan dispatch executor +
   reviewer pairs concurrently, not sequentially per task.

**Expected impact:** ~30-40% wall-clock reduction on plans with parallel groups.

---

## Expected aggregate impact

For a typical 5-task feature flow (`/task` → `/plan` → `/do` → `/review`):

| Metric                                | Before  | After   | Reduction |
| ------------------------------------- | ------- | ------- | --------- |
| Sub-agent dispatches (worst case)     | ~50     | ~17     | 66%       |
| Sub-agent dispatches (typical)        | ~25     | ~14     | 44%       |
| Phases tracked across 4 skills        | 27      | 14      | 48%       |
| Reference file lines loaded per run   | ~2000   | ~400    | 80%       |
| Sequential waits in `/do` per task    | 3       | 1       | 66%       |
| Wall-clock for typical run            | 1.0×    | ~0.4×   | ~60%      |

The wall-clock estimate is based on:

- Most agent dispatches dominated by codebase exploration + LLM round-trip,
  ~30-90s each.
- Sequential waits dominate; parallelism on independent tasks has been left on
  the table.
- Cache misses on reference files have multiplicative cost when the cache
  refreshes between phases.

---

## Risks and mitigations

| Risk                                                                          | Mitigation                                                                                                                                          |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Merging spec+quality reviewer reduces strictness and lets bugs slip through.  | Keep both checklists in the merged agent; require both to pass before DONE. Add an end-to-end smoke test on a known buggy plan.                     |
| Dropping `code-polisher` lets cruft accumulate.                               | Move the cleanup bullets into `task-executor` self-review; rely on project formatter/linter. Cruft that escapes self-review is caught by `/review`. |
| Inlined report writing loses structure.                                       | Keep a minimal markdown template in SKILL.md and a Write call; the structure is identical, only the agent dispatch goes away.                       |
| Removing `plan-reviewer` lets weak plans through.                             | Keep the 6-bullet self-check in `plan-architect`'s output. The same checklist runs, just inside the architect.                                      |
| Conditional `doc-updater` confuses users who relied on auto-docs.             | Document the change; add a one-line opt-in flag (`--update-docs`) and reference it in `/do` SKILL.md.                                               |
| Style drift after dropping copyedit agent.                                    | Inline checklist + occasional manual `/yoke:fix` pass. The drift is limited to ~1-2 page markdowns.                                                 |
| Lost agent-team mode for cross-layer plans.                                   | Keep `agent-team` as a third routing rule. Most users do not enable the feature flag — the rule is dormant for them anyway.                         |
| revdiff users miss the auto-loop.                                             | Document `/revdiff <path>` as the manual replacement; keep one-shot offer in Complete.                                                              |

---

## What we are explicitly NOT changing

- **TodoWrite tracking.** It is local state, not a dispatch. Cheap, readable.
- **`task-executor` itself.** It is the load-bearing implementer; merging its
  responsibilities into the orchestrator would burn the main context.
- **`single-fix-agent`.** Genuine parallelizable unit of work in `/review`.
- **`validator` and `formatter`.** Both are tight, run shell commands, use Haiku.
  Worth running, just in parallel where safe.
- **The four-skill split itself.** `/task`, `/plan`, `/do`, `/review` are clean
  boundaries; the issue is each skill's internal orchestration, not the boundaries.
- **Conventional-commit format.** Already short and consistent.

---

## Validation checklist (run after each phase's commits)

Structural and smoke checks. Detailed per-edit validation lives in the operational
notes appendix (use `yoke-create`'s Phase 5 prose + structure agents).

- [ ] `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json'))"` — manifests parse.
- [ ] `head -1 skills/*/SKILL.md` — every file starts with `---`.
- [ ] `claude --plugin-dir .` — plugin loads, all four slash commands resolve.
- [ ] `/yoke:hi` — overview still lists the four skills.
- [ ] `pnpm run format:check` — markdown still passes Prettier.
- [ ] Run `yoke-create` Phase 5 agents (prose + structure) on every modified
      `SKILL.md` and agent file in this phase. See operational notes §6.
- [ ] Smoke test against the synthetic baseline ticket
      (`docs/ai/test-baseline/`) — `/task` → `/plan` → `/do` → `/review`. See
      operational notes §4.
- [ ] Compare end-to-end wall-clock against the baseline measured before
      Phase 1 began.

---

# Operational Notes for a Fresh Session

This appendix is the **cold-start brief**: it gives a fresh Claude session
everything it needs to begin executing the plan without re-deriving context. Read
the main plan first; then use this appendix as the operational guide.

## §1. Worked example — full target file for the first agent merge

The simplest agent merge is **Phase 3.1**: combining `task-explorer` and
`task-architect` into a single `task-investigator`. Use this as the template for
the other two merges (`plan-architect`, `task-reviewer`).

**Target file: `skills/task/agents/task-investigator.md`**

```markdown
---
name: task-investigator
description: Investigates the codebase area touched by a new task — entry points with file:line, patterns to reuse, tests in the area, integration risks. Output feeds /task's writing phase.
tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, WebSearch
model: sonnet
color: yellow
---

You are a code investigator. You map the area touched by a new task: where it
lands, which patterns it must follow, what could break.

### Step 0 — Context

If `.claude/yoke-context.md` exists — read it. Use the data as additional
context: stack, architecture, validation commands. File absent — skip.

## Mission

Give the orchestrator enough information to write a self-contained task file.
Do not design the implementation — that is `/plan`'s job. Stop at: entry points,
patterns, tests, risks, reusable code.

## Process

**1. Entry points and change surface**

- Find files and functions the task will touch. Cite `path:line`.
- If multiple candidate locations exist, pick the primary one and note alternatives.

**2. Patterns and conventions**

- Identify 1-2 similar implementations in the project. For each: path, structure,
  what to reuse directly.
- Note conventions enforced in the area (naming, layering, error handling).

**3. Tests**

- List existing tests covering the area (path + brief scope).
- If no tests exist — say so. Coverage gap raises complexity.

**4. Integration and risks**

- List dependencies a change would touch — interfaces, exported types, shared state.
- Flag fragile spots: large files without tests, multiple consumers of a type,
  recent churn.

**5. Reusable building blocks**

- Existing utilities, components, or patterns that cover part of the requirements.
  Cite path.

## Output format

\`\`\`
## Entry points
- `<path>:<line>` (`<fn or symbol>`) — <role>

## Patterns to reuse
- `<path>` — <pattern name>: <what to reuse>

## Tests
- `<path>` — <scope>
- Coverage gap: <area without tests, if any>

## Integration and risks
- <interface or shared state>: <consumers / fragility>

## Reusable building blocks
- `<path>:<line>` — <utility or component>

## Essential reads (for the writing phase)
- `<path>` — <why>
\`\`\`

Cite paths and line numbers. Active voice. Concrete files instead of
"the auth module".
```

**Companion edits in `skills/task/SKILL.md`:**

- Phase 2 — replace the two-agent dispatch block (lines ~64-117 in the current
  file; verify with grep before editing) with a single dispatch:

```
**Step 1 — Launch task-investigator through the Agent tool:**

Prompt to the agent:

\`\`\`
Investigate the codebase area for this task: [paste the ticket essence].

Find and document:
1. Entry points with file:line
2. Patterns to reuse (1-2 similar implementations)
3. Tests covering the area, or note their absence
4. Integration risks and fragile dependencies
5. Reusable utilities or components
\`\`\`

**Step 2 — Validate stop criteria** (no separate file-read pass):
- [ ] Entry points identified with line numbers
- [ ] Patterns to reuse named with example files
- [ ] Tests found or absence confirmed
- [ ] Risk zones flagged

If any item is open — re-dispatch task-investigator with a narrower scope.
Otherwise → Phase 3.
```

- Top of file — replace the agent registry (lines 13-17):

```
Delegate codebase investigation through the Agent tool:

- Investigation → `agents/task-investigator.md`
```

- Delete `skills/task/agents/task-explorer.md` and
  `skills/task/agents/task-architect.md` only **after** the new agent passes
  smoke tests (see §7).

Apply the same shape to `plan-architect` (3-way merge of `plan-explorer` +
`plan-designer` + `plan-reviewer`-as-self-check) and `task-reviewer` (2-way
merge of `spec-reviewer` + `quality-reviewer`).

---

## §2. Cross-skill dependency map

Before editing or moving any file referenced by another skill, **check this map**.
Breaking a cross-skill reference silently breaks a downstream skill at runtime.

**Files referenced across skills (as of plan writing — verify with grep before
editing):**

| File                                                | Referenced from                                              | Notes                                                                                |
| --------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| `skills/gca/reference/commit-convention.md`         | `task` (×2), `plan` (×2), `do` (×6), `review` (×2)            | **Do not touch.** All four core skills depend on it.                                 |
| `skills/do/agents/validator.md`                     | `review/SKILL.md:19`, `review/SKILL.md:119`                   | If renamed, moved, or inlined into `/do`, **`/review` Phase 4d must be updated**.    |
| `skills/do/agents/formatter.md`                     | `review/SKILL.md:20`, `review/SKILL.md:122`                   | Same as validator. `/review` Phase 4e depends on it.                                 |
| `skills/gp/agents/git-pre-checker.md:43-54`         | `do/SKILL.md:291`                                             | Used in revdiff path for default-base resolution. Read-only reference.               |
| `lib/notify.sh`                                     | All four skills (multiple call sites)                        | Script stays. **Stop calling it from intermediate phases**, keep at terminal phases. |
| `hooks/notify.sh` and `hooks/hooks.json`            | Plugin loader (auto-discovered)                               | Hooks are independent from skill notifications. **Do not touch.**                    |

**Implication for Phase 4 (inline single-purpose agents):** if `/do`'s
`report-writer` is inlined into the orchestrator, that does **not** affect
`/review` (review has its own `review-report-writer`). But if you are tempted to
inline `validator` or `formatter` into `/do`, **stop** — `/review` reads them by
absolute path and would break. Keep `validator.md` and `formatter.md` as
standalone agent files even when their callers shrink.

**Verify before editing:** run

```bash
grep -rn "<file-being-changed>" skills/ docs/ commands/
```

to confirm the call sites match the table. If new call sites have appeared,
update them in the same commit.

---

## §3. Single-PR shipping policy

The user has chosen a **single PR for all six phases**. This shapes how the work
runs:

- **One feature branch.** Name suggestion: `optimize-core-skills`. Created at
  the start, merged at the end.
- **Phase = commit group.** Each phase produces one or more commits. The phase
  boundary is a commit boundary, not a PR boundary. Use the conventional commit
  format from `skills/gca/reference/commit-convention.md`.
- **Recommended commit cadence per phase:**
  - One commit per skill modified inside a phase (Phase 1 → 4 commits if all
    four skills change in that phase).
  - Or one commit per logical change if the change touches one skill only.
  - Avoid one giant commit per phase — granular commits make per-phase
    revert easier (see §10).
- **No version bump.** `plugin.json` and `marketplace.json` stay at the current
  version (`1.0.0` as of plan writing). The user releases manually via
  `/yoke-release` after the PR merges.
- **PR title:** `optimize: reduce core skill latency by collapsing pipelines`
  or similar. Body: paste the table from "Expected aggregate impact" + the
  baseline-vs-after measurements from §4.

**Branching specifics:**

```bash
git checkout main && git pull
git checkout -b optimize-core-skills
# ... phases 1-6, with commits ...
git push -u origin optimize-core-skills
gh pr create --title "..." --body "..."
```

The user runs the actual `git push` and `gh pr create` commands (or approves
them). Never push without confirmation.

---

## §4. Baseline measurement — synthetic ticket

**Before any change in Phase 1, measure baseline.** Without baseline numbers,
the optimization claim ("≈60% faster") cannot be verified.

### 4.1 Create the baseline ticket

Path: `docs/ai/test-baseline/test-baseline-task.md`

Suggested ticket — small, real, runs through all four skills cleanly:

```markdown
# Add a --version flag handler to lib/notify.sh

**Slug:** test-baseline
**Ticket:** —
**Complexity:** trivial
**Type:** general

## Task

Add a `--version` flag to `lib/notify.sh` that prints the script's version
(read from a single `VERSION="x.y.z"` line at the top of the file) and exits 0.

## Context

### Area architecture

`lib/notify.sh` is invoked by skills via `bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh ...`.
The script currently parses flags via getopts and supports `--type`, `--skill`,
`--phase`, `--slug`, `--title`, `--body`.

### Files to change

- `lib/notify.sh` — add VERSION constant + `--version` flag handler

### Patterns to reuse

- Existing flag parsing pattern in the same file (use the same getopts loop).

### Tests

- No automated tests for `lib/notify.sh`. Verify manually via curl-style command.

## Requirements

1. `lib/notify.sh --version` prints exactly `notify.sh <version>` and exits 0.
2. Other flags continue to work unchanged.

## Constraints

- Do not change the existing notification behavior.
- Do not add external dependencies.

## Verification

- `bash lib/notify.sh --version` → prints `notify.sh 1.0.0`, exit code 0.
- `bash lib/notify.sh --type STAGE_COMPLETE --skill task --title "x" --body "y"` →
  same behavior as before (sends notification or no-op if env vars unset).

## Materials

- `lib/notify.sh`
```

**Why this ticket:** trivial complexity (≤ 1 file, ≤ 10 lines), real surface
(touches a real script), end-to-end verifiable, no UI / no `frontend-guide.md`
load, runs cleanly through `/task` → `/plan` → `/do` → `/review`.

### 4.2 Measurement procedure

```bash
# Baseline (before any changes)
git checkout main
time claude --plugin-dir . --print "/yoke:task add --version flag to lib/notify.sh" > /tmp/baseline-task.log 2>&1
time claude --plugin-dir . --print "/yoke:plan docs/ai/test-baseline/test-baseline-task.md" > /tmp/baseline-plan.log 2>&1
time claude --plugin-dir . --print "/yoke:do docs/ai/test-baseline/test-baseline-plan.md" > /tmp/baseline-do.log 2>&1
time claude --plugin-dir . --print "/yoke:review test-baseline" > /tmp/baseline-review.log 2>&1
```

Record the four `time` outputs into `docs/ai/test-baseline/baseline-measurements.md`
as a markdown table. Include: real time, agent dispatch count (grep the logs for
`Agent` invocations), and number of files changed.

After each phase's commits, re-run the four commands on the synthetic ticket
(reset the test-baseline state with `git stash` of any changes, rerun, then
`git stash pop`). Append results to the same measurements file.

**Important:** the synthetic ticket must be re-runnable. After each measurement,
revert any actual changes the run made to `lib/notify.sh` (the run will
implement the ticket each time):

```bash
git checkout -- lib/notify.sh docs/ai/test-baseline/
```

**Alternative measurement (if --print mode is not viable):** run interactively,
record time-to-first-output and time-to-final-summary using a stopwatch or
shell-side timestamp logging.

---

## §5. Use of `yoke-create` skill flow during implementation

The user has asked to incorporate `yoke-create`'s validation flow rather than
running the full skill. Specifically, **Phase 5 of `yoke-create`**
(`.claude/skills/yoke-create/SKILL.md:257-318`) defines two validation agents:

- **Agent 3 — Prose check** (active voice, positive statements, concrete
  language, no filler, brevity, imperative).
- **Agent 4 — Structure validation** (10 checks: frontmatter, name match,
  description quality, agent frontmatter, references, body size <500 lines,
  numbered phases, TodoWrite mention, Rules section).

**Apply both checks** after editing any `SKILL.md` or agent file in this
refactor. Procedure:

1. Make the edit.
2. Dispatch yoke-create's Agent 3 prompt verbatim, scoped to the file just
   edited (e.g., `skills/task/SKILL.md` and any new agent in `skills/task/agents/`).
3. Dispatch yoke-create's Agent 4 prompt verbatim, same scope.
4. If issues > 0, fix inline before moving on.

Do **not** invoke `/yoke-create` end-to-end — it expects to be creating a new
skill, not validating modifications to existing ones. Only the Phase 5 agent
prompts are reused.

The full `/yoke-create` skill is not the right tool for this refactor because it
assumes a new skill is being scaffolded and runs Phases 0-4 (preflight, analyze,
design, confirm, implement) before validation. This refactor edits existing
skills.

---

## §6. Safe order of operations within an agent merge

When merging two agents into one (Phase 3), follow this order **per merge** to
keep the working tree in a runnable state at every commit boundary:

1. **Create the new agent file.** E.g., `skills/task/agents/task-investigator.md`.
   At this point both old agents and the new one coexist.
2. **Run yoke-create Phase 5 validation** (§5) on the new agent file. Fix any
   issues.
3. **Update the parent SKILL.md to reference the new agent.** Replace the old
   Agent dispatch block(s) with a single new dispatch. The old agents still
   exist on disk but are no longer referenced.
4. **Smoke test** against the synthetic baseline ticket (§4). Confirm the skill
   completes end-to-end and produces the expected artifact shape.
5. **Commit.** Use a conventional message:
   `optimize(task): replace explorer+architect with task-investigator`.
6. **Delete the old agent files.** `git rm skills/task/agents/task-explorer.md
   skills/task/agents/task-architect.md`.
7. **Run validation checklist** from the main plan.
8. **Commit the deletions.** Same scope, separate message:
   `optimize(task): remove deprecated explorer and architect agents`.

This two-commit pattern (replace, then delete) makes a single-step revert
possible if the new agent is found insufficient — revert commit 8 first to
restore the old files, then revert commit 5 to restore the SKILL.md wiring.

---

## §7. Verify line references before editing

Line numbers cited throughout this plan and in agent prompts are correct **as
of plan writing** (current branch `main`, current state). Between writing and
execution, files may have shifted.

**Before any edit that depends on a line range,** run:

```bash
grep -n "<distinctive snippet>" <file>
```

Use a unique short string from the surrounding context (e.g., a section header
like `**1.** Read the plan file in full.`) to locate the actual current line
range. Re-derive line numbers from the grep output. **Never trust the cited
line numbers blindly** if the file has been touched since plan writing.

For changes to `SKILL.md` files specifically, prefer matching by section
heading text (e.g., `## Phase 3 — Synthesize`) rather than by line number,
since headings are stable and line numbers drift.

---

## §8. Hooks and notification system

The plan calls for "drop notification spam" but is precise about scope:

**What stays untouched:**

- `hooks/hooks.json` and `hooks/notify.sh` — these are **plugin-level hooks**
  (Telegram notifications wired to Claude Code lifecycle events). They are
  auto-discovered by Claude Code from the `hooks/` directory and run independent
  of skill orchestration. Do not delete or modify.
- `lib/notify.sh` — the **shared script** that skills `bash`-invoke for sending
  notifications. The script stays.

**What changes:**

- The skill orchestrators (`SKILL.md` files) currently invoke
  `bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh ...` at multiple phase boundaries
  (e.g., `task/SKILL.md:144`, `plan/SKILL.md:153`). Phase 1 of the optimization
  removes these intermediate calls.

**Keep these notification call sites:**

- ACTION_REQUIRED — right before any `AskUserQuestion` invocation (user input).
- STAGE_COMPLETE — at the terminal phase of each skill (success summary).
- ALERT — in `/do` when a task is `BLOCKED` (kept from current behavior).

**Drop these notification call sites:**

- Phase boundaries that are not terminal and not user-input gates.
- Per-task notifications inside `/do`'s execute loop.

Search for all current call sites with:

```bash
grep -rn "notify.sh" skills/
```

Annotate each as keep / drop in your scratch notes before Phase 1 commit.

---

## §9. Rollback procedures

Each phase has a different risk profile. Rollback strategies:

| Phase | Rollback                                                                                                                  |
| ----- | -------------------------------------------------------------------------------------------------------------------------- |
| 1     | `git revert <commit-range>` for the phase's commits. Cosmetic changes only — low risk.                                     |
| 2     | Same as Phase 1. Reference inlining is reversible.                                                                         |
| 3     | Most fragile. Per merge, revert the deletion commit first (restores files), then the replacement commit (restores wiring). |
| 4     | `git revert` per inline. Each report inline is one commit — granular revert.                                                |
| 5     | The behavior-visible phase. If users push back: `git revert` `code-polisher` removal first; `doc-updater` removal second.   |
| 6     | Parallel dispatch. If parallelism causes git races, revert and re-do as sequential — still wins from agent merges.         |

**If multiple phases need rollback,** revert in reverse order (latest phase
first) to keep the dependency graph valid.

**Detection signals for rollback:**

- Smoke test fails on the baseline ticket.
- `claude --plugin-dir .` fails to load the plugin.
- `/yoke:hi` does not list all four skills.
- Wall-clock measurement shows regression vs prior phase.
- Validation checklist fails any item.

---

## §10. Risky behavior changes — user-visible flags

Two changes in Phase 5 are **user-visible** and warrant a heads-up in the PR
description:

**a) `code-polisher` removal.**

Users who relied on automatic post-implementation simplification will notice
diffs are slightly larger. Mitigation: the `task-executor` self-review now
includes the cleanup checklist (debug logs, commented-out code, unused
imports). Quality is preserved; the dispatch is gone.

**b) `doc-updater` made opt-in.**

Default behavior changes: `/do` no longer auto-updates README/CHANGELOG/JSDoc.
Users can opt in via a flag (suggested: `--update-docs` passed to `/do`, or a
`update_docs: true` field in the plan's frontmatter). Document the new flag in:

- `skills/do/SKILL.md` Phase 5 section.
- `docs/do.md` (the user-facing doc).
- The PR description.

Both changes go in **Phase 5**. Group them into one or two commits with a
clear conventional message:

```
optimize(do): remove code-polisher phase, fold cleanup into self-review
optimize(do): make doc-updater opt-in via --update-docs
```

---

## §11. Memory and context for the fresh session

A fresh Claude session starting this work will load:

- `CLAUDE.md` (project root) — yoke conventions, content language English,
  validation commands, kebab-case files.
- The user's auto-memory at `~/.claude/projects/.../memory/MEMORY.md` —
  notably "Use plugin-dev skills" and "Sub-agent tool scopes" feedback.
- This plan file.

**Before starting, the fresh session should:**

1. Read `CLAUDE.md` (auto-loaded).
2. Read this entire plan file end to end.
3. Read `.claude/skills/yoke-create/SKILL.md` Phase 5 for the validation prompt
   templates.
4. Read each of the four target `SKILL.md` files to verify current line numbers.
5. Run `git status` and `git log -10` to confirm the working tree is clean and
   on `main`.
6. Create the baseline ticket (§4) and measure baseline.
7. Create the feature branch and start Phase 1.

**Things the fresh session should NOT do:**

- Bump `plugin.json` or `marketplace.json` versions (per user decision).
- Push to remote without explicit user confirmation.
- Run `/yoke-release` (release is manual).
- Modify `hooks/`, `lib/notify.sh`, or `skills/gca/reference/commit-convention.md`.
- Use `/yoke-create` end-to-end (only its Phase 5 prompts, scoped per file).
- Modify `skills/do/agents/validator.md` or `skills/do/agents/formatter.md` in
  a way that breaks `/review`'s absolute-path references.
- Use destructive git operations (`reset --hard`, `push --force`, branch
  deletion) without explicit confirmation.

**Open questions to surface to the user before starting:**

- None — the plan is self-contained given the answers already provided
  (single PR, no version bump, synthetic baseline, yoke-create Phase 5 for
  validation). If new ambiguity arises during execution, surface via
  AskUserQuestion at the moment it appears, not preemptively.

---

## §12. Quick reference — file inventory and what happens to each

| Path                                              | Phase | Action                                                                       |
| ------------------------------------------------- | ----- | ---------------------------------------------------------------------------- |
| `skills/task/SKILL.md`                            | 1,2,3 | Edit: drop copyedit, drop file-read pass, inline checklist, single dispatch. |
| `skills/task/agents/task-explorer.md`             | 3     | Delete after `task-investigator` ships.                                       |
| `skills/task/agents/task-architect.md`            | 3     | Delete after `task-investigator` ships.                                       |
| `skills/task/agents/task-investigator.md`         | 3     | **Create.** See §1 for full template.                                          |
| `skills/task/reference/synthesize-guide.md`       | 2     | Demote — inline checklist into SKILL.md, stop loading.                        |
| `skills/task/reference/frontend-guide.md`         | 2     | Conditional load only.                                                         |
| `skills/task/reference/elements-of-style-rules.md`| 1     | Stop loading; inline 5-bullet checklist.                                       |
| `skills/task/examples/*.md`                       | 2     | Stop preloading.                                                               |
| `skills/plan/SKILL.md`                            | 1,2,3 | Edit: drop copyedit, drop reviewer phase, inline routing, single dispatch.   |
| `skills/plan/agents/plan-explorer.md`             | 3     | Delete after `plan-architect` ships.                                          |
| `skills/plan/agents/plan-designer.md`             | 3     | Delete after `plan-architect` ships.                                          |
| `skills/plan/agents/plan-reviewer.md`             | 3     | Delete; checks fold into `plan-architect` self-review.                       |
| `skills/plan/agents/plan-architect.md`            | 3     | **Create** as 3-way merge.                                                    |
| `skills/plan/reference/routing-rules.md`          | 2     | Replace 9-row matrix with 3 inline rules.                                     |
| `skills/plan/reference/plan-format.md`            | 2     | Inline minimal template into SKILL.md.                                        |
| `skills/plan/examples/*.md`                       | 2     | Stop preloading.                                                               |
| `skills/do/SKILL.md`                              | 3,4,5,6 | Edit: combined reviewer, drop polish, opt-in doc-updater, parallel valid+fmt.|
| `skills/do/agents/task-executor.md`               | 5     | Edit: add cleanup bullets to self-review.                                     |
| `skills/do/agents/spec-reviewer.md`               | 3     | Delete after `task-reviewer` ships.                                          |
| `skills/do/agents/quality-reviewer.md`            | 3     | Delete after `task-reviewer` ships.                                          |
| `skills/do/agents/task-reviewer.md`               | 3     | **Create** as 2-way merge.                                                    |
| `skills/do/agents/code-polisher.md`               | 5     | Delete.                                                                       |
| `skills/do/agents/doc-updater.md`                 | 5     | Keep file; SKILL.md makes its dispatch conditional.                           |
| `skills/do/agents/report-writer.md`               | 4     | Delete; orchestrator writes report inline.                                    |
| `skills/do/agents/validator.md`                   | —     | **Do not move or rename** — `/review` depends on the path.                    |
| `skills/do/agents/formatter.md`                   | —     | **Do not move or rename** — `/review` depends on the path.                    |
| `skills/do/reference/status-protocol.md`          | 3,5   | Edit: combined review, iterations 3→2.                                        |
| `skills/do/reference/report-format.md`            | 2     | Inline minimal template into SKILL.md.                                        |
| `skills/review/SKILL.md`                          | 4,6   | Edit: drop issue-fixer layer, inline report-writer, parallel valid+fmt.       |
| `skills/review/agents/code-reviewer.md`           | —     | Keep.                                                                         |
| `skills/review/agents/issue-fixer.md`             | 4     | Delete; orchestrator dispatches single-fix-agent directly.                   |
| `skills/review/agents/single-fix-agent.md`        | —     | Keep — genuine parallelizable unit of work.                                   |
| `skills/review/agents/review-report-writer.md`    | 4     | Delete; orchestrator writes report inline.                                    |
| `skills/review/reference/review-format.md`        | 2     | Inline minimal template into SKILL.md.                                        |
| `lib/notify.sh`                                   | —     | **Do not touch.** Reduce call sites in SKILL.md instead.                       |
| `hooks/`                                          | —     | **Do not touch.**                                                              |
| `skills/gca/reference/commit-convention.md`       | —     | **Do not touch.**                                                              |
| `skills/gp/agents/git-pre-checker.md`             | —     | **Do not touch** (read-only reference from `/do`).                             |
| `.claude-plugin/plugin.json`                      | —     | **Do not bump version.**                                                       |
| `.claude-plugin/marketplace.json`                 | —     | **Do not bump version.**                                                       |
| `docs/ai/test-baseline/test-baseline-task.md`     | pre-1 | **Create** as baseline. See §4.1.                                              |
| `docs/ai/test-baseline/baseline-measurements.md`  | pre-1, after each phase | Append measurements. See §4.2.                            |
