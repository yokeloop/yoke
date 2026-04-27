# Baseline Measurements — Skill Optimization (#13)

Synthetic ticket: `docs/ai/test-baseline/test-baseline-task.md` (add `--version`
flag to `lib/notify.sh`).

Wall-clock measurement via `claude --print` is not viable: every core skill
gates on `AskUserQuestion`, which has no responder in headless mode. Recording
**structural** metrics instead — dispatch count, phase count, file inventory,
LOC. Structural metrics are exactly what the optimization targets; wall-clock
is a derivative.

After each phase's commits, append a new column to the tables below.

---

## Per-skill structural metrics

### `/task`

| Metric                                        | Baseline (commit 318add9) |
| --------------------------------------------- | ------------------------- |
| SKILL.md lines                                | 286                       |
| Phases tracked                                | 6                         |
| Sub-agents dispatched (typical run)           | 3 (explorer + architect + copyeditor) |
| Sub-agent files in `agents/`                  | 2 (`task-explorer.md`, `task-architect.md`) |
| Reference files                               | 3 (`synthesize-guide.md` 265, `frontend-guide.md` 234, `elements-of-style-rules.md` 44) |
| Examples                                      | 2 (`simple-task.md` 127, `complex-task.md` 220) |
| Reference + examples lines loaded per run     | ~620 (synthesize 265 + style 44 + 1 example ~150 + frontend conditional 234) |
| Notification calls                            | 2 (ACTION_REQUIRED in Synthesize, STAGE_COMPLETE in Complete) |
| Auto-commit step                              | Separate Phase 5 |

### `/plan`

| Metric                                        | Baseline (commit 318add9) |
| --------------------------------------------- | ------------------------- |
| SKILL.md lines                                | 315                       |
| Phases tracked                                | 8                         |
| Sub-agents dispatched (typical run)           | 3-8 (explorer + designer + reviewer ×1-5 + copyeditor) |
| Sub-agent files in `agents/`                  | 3 (`plan-explorer.md`, `plan-designer.md`, `plan-reviewer.md`) |
| Reference files                               | 3 (`plan-format.md` 94, `routing-rules.md` 119, `elements-of-style-rules.md` 44) |
| Examples                                      | 2 (`simple-plan.md` 130, `complex-plan.md` 156) |
| Reference + examples lines loaded per run     | ~400 (format 94 + routing 119 + style 44 + 1 example ~140) |
| Notification calls                            | 2 (ACTION_REQUIRED in Design, STAGE_COMPLETE in Complete) |
| Auto-commit step                              | Separate Phase 7 |

### `/do`

| Metric                                        | Baseline (commit 318add9) |
| --------------------------------------------- | ------------------------- |
| SKILL.md lines                                | 312                       |
| Phases tracked                                | 7                         |
| Sub-agents dispatched (worst case, 5 tasks)   | ~40 (5 × (executor + spec×3 + qual×3) + polish + validator + doc + format + report) |
| Sub-agents dispatched (typical, 5 tasks)      | ~15 (5 × (executor + spec + qual) + validator + format + report) — drops doc + polish if minimal |
| Sub-agent files in `agents/`                  | 8 (`task-executor`, `spec-reviewer`, `quality-reviewer`, `code-polisher`, `doc-updater`, `validator`, `formatter`, `report-writer`) |
| Reference files                               | 2 (`status-protocol.md` 147, `report-format.md` 89) |
| Sequential review iters per task              | up to 3 (spec) + 3 (quality) = 6 |
| Notification calls                            | 2 (ALERT on BLOCKED, STAGE_COMPLETE in Complete) |
| Auto-commit step                              | Inlined into Phase 6c (separate sub-step) |

### `/review`

| Metric                                        | Baseline (commit 318add9) |
| --------------------------------------------- | ------------------------- |
| SKILL.md lines                                | 187                       |
| Phases tracked                                | 6                         |
| Sub-agents dispatched (typical run)           | 4-5 (code-reviewer + issue-fixer→single-fix-agents + validator + formatter + review-report-writer) |
| Sub-agent files in `agents/`                  | 4 own (`code-reviewer`, `issue-fixer`, `single-fix-agent`, `review-report-writer`) + 2 reused from `/do` (`validator`, `formatter`) |
| Reference files                               | 1 (`review-format.md` 101) |
| Notification calls                            | 2 (ACTION_REQUIRED in Select, STAGE_COMPLETE in Complete) |
| Auto-commit step                              | Inlined into Phase 5c (separate sub-step) |

---

## Aggregate baseline

| Metric                                          | Baseline | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 |
| ----------------------------------------------- | -------- | ------- | ------- | ------- | ------- | ------- | ------- |
| Total SKILL.md lines (4 skills)                 | 1100     | 1062    | 1290    | 1165    | 1180    |         |         |
| Phases tracked across 4 skills                  | 27       | 25      | 25      | 22      | 22      |         |         |
| Sub-agent files (4 skills, dedicated)           | 16       | 16      | 16      | 12      | 9       |         |         |
| Sub-agent dispatches (worst case, 5-task plan)  | ~50      | ~48     | ~48     | ~32     | ~29     |         |         |
| Sub-agent dispatches (typical, 5-task plan)     | ~25      | ~23     | ~23     | ~17     | ~14     |         |         |
| Mandatory reference LOC by orchestrators        | ~620     | ~426    | ~5      | ~5      | ~5      |         |         |
| Sequential review waits in `/do` per task       | up to 6  | up to 6 | up to 6 | up to 3 | up to 3 |         |         |
| Intermediate notification calls (per skill)     | 2/2/2/2  | 1/1/2/2 | 1/1/2/2 | 1/1/2/2 | 1/1/2/2 |         |         |
| Files changed by /do on synthetic ticket        | 1 (`lib/notify.sh`) target | not measured | not measured | not measured | not measured |     |         |

---

## Notes

- Worst-case dispatch numbers come from the plan's own analysis (§ Goal table).
- "Typical" assumes 1 spec-review iteration and 1 quality-review iteration per
  task, no `code-polisher` churn beyond a single dispatch, and `doc-updater`
  running once.
- "Mandatory reference LOC by orchestrators" = lines the orchestrator must read
  on every cold run (excluding agent-internal reads — those are inside the
  sub-agent's context, not the main thread). Baseline: synthesize 265 + style 44
  + simple-task example 127 + plan-format 94 + routing 119 + plan style 44
  ≈ ~620 (frontend-guide conditional). Phase 1 dropped style ×2 + examples
  ≈ -194. Phase 2 inlined synthesize checklist + plan-format template +
  routing rules; only a handful of cross-references remain ≈ ~5.
- Re-running each skill on the synthetic ticket would touch `lib/notify.sh`;
  per `docs/skill-optimization-plan.md` §4.2, revert with
  `git checkout -- lib/notify.sh docs/ai/test-baseline/` after each measurement.
- This file is appended after each phase's commits via per-skill diff against
  the baseline column.
