# Report: 21-do-universal-rework

**Plan:** docs/ai/21-do-universal-rework/21-do-universal-rework-plan.md
**Mode:** sub-agents (sequential)
**Status:** ✅ complete

## Tasks

| #   | Task                                                | Status  | Commit    | Concerns |
| --- | --------------------------------------------------- | ------- | --------- | -------- |
| 1   | Convert do/SKILL.md to input-shape router, → .yoke/ai | ✅ DONE | `2f11387` | —        |
| 2   | Create reference/mode-inline.md                     | ✅ DONE | `5cd869b` | —        |
| 3   | Move plan-architect + task-investigator into do/agents | ✅ DONE | `204a111` / `10cdc66` | prose edit stranded by aborted git add, committed separately |
| 4   | Create reference/mode-sub-agents.md                 | ✅ DONE | `1cdf226` | —        |
| 5   | Create reference/mode-team.md                       | ✅ DONE | `5cd869b` | —        |
| 6   | Add `team` to report Mode field                     | ✅ DONE | `5cd869b` | —        |
| 7   | Deprecate task/plan, fix catalog counts             | ✅ DONE | `06f7a8f` | —        |
| 8   | Repoint task/plan handoffs to /yoke:do              | ✅ DONE | `1c9a9d5` | —        |
| 9   | Update README/CLAUDE prose; close #5                | ✅ DONE | `3486439` | —        |
| 10  | Regenerate 16-skill catalog; actualize docs/do.md   | ✅ DONE | `b1b8329` | —        |
| 11  | Validation                                          | ✅ DONE | —         | —        |

## Post-implementation

| Step          | Status     | Commit |
| ------------- | ---------- | ------ |
| Validate      | ✅ pass    | —      |
| Documentation | ⏭️ skipped | —      |
| Format        | ✅ done    | (husky per-commit) |

## Concerns

### Task 3: stranded prose edit

The T3 `git add` listed the pre-`git mv` agent paths and aborted, committing only the renames. The `task-investigator.md` prose repoint ("belongs to `/yoke:do`'s Plan phase") was caught during validation and committed separately as `10cdc66`.

### docs/do.md drift caught in validation

`docs/do.md` (source for `do.mdx`) still described the old plan-file-driven do. Rewritten for the universal 3-mode do and re-synced (folded into Task 10) so `/yoke:sync-docs --check` stays green.

### Deferred by design (per task constraints)

- **Team mode** is detect + sub-agents-per-sub-issue fallback; real `TeamCreate` left as a marked extension point in `mode-team.md`.
- `do`'s one-line catalog description ("Executes a task per plan.") is narrower than its new universal scope; triggers remain valid. A description polish is a candidate for the 2.0 release pass.

## Validation

`head -1 skills/*/SKILL.md deprecated/*/SKILL.md` → all `---` ✅
`python3 -c "import json; …plugin.json; marketplace.json"` → OK ✅
`pnpm run format:check` → clean ✅
`/yoke:sync-docs --check` → no drift ✅
`grep -rc docs/ai skills/do/` → 0 ✅
`grep -rn "skills/plan/agents|skills/task/agents" skills/` → none ✅
`grep -rn "/yoke:task|/yoke:plan" skills/ README.md CLAUDE.md | grep -v deprecated/` → none ✅
fix/review do-agent paths (task-executor, code-polisher, validator, doc-updater, formatter) → all resolve ✅
`printf '%s\n' skills/*/` → 16; `deprecated/*/` → 2 (task, plan) ✅
No automated test suite (markdown plugin) — N/A

## Changes summary

| File                                          | Action   | Description                                              |
| --------------------------------------------- | -------- | ------------------------------------------------------- |
| `skills/do/SKILL.md`                          | modified | rewritten as input-shape router; `.yoke/ai/`; one ignore probe |
| `skills/do/reference/mode-inline.md`          | created  | inline mode (no plan file, no pause)                    |
| `skills/do/reference/mode-sub-agents.md`      | created  | plan → pause → execute pipeline (absorbed task/plan)    |
| `skills/do/reference/mode-team.md`            | created  | detect PRD sub-issues → per-sub-issue fallback + extension point |
| `skills/do/reference/report-format.md`        | modified | added `team` to Mode field                              |
| `skills/do/agents/{plan-architect,task-investigator}.md` | moved | git mv from skills/plan, skills/task; prose repointed |
| `deprecated/{task,plan}/`                     | moved    | task/plan skills out of auto-discovery (+ their docs)   |
| `skills/sync-docs/{SKILL.md,reference/sync-spec.md}` | modified | catalog counts 18 → 16, dropped plan/task               |
| `skills/{issues,handoff,bootstrap,help,fix}/SKILL.md`, `skills/gca/reference/commit-convention.md` | modified | handoffs repointed to /yoke:do |
| `README.md`, `CLAUDE.md`, `docs/do.md`        | modified | universal-do prose; catalog regenerated                 |
| `site/src/content/docs/skills/*.mdx`          | modified | 16-skill catalog; task.mdx/plan.mdx removed             |

## Commits

- `2f11387` #21 refactor: convert do SKILL.md to input-shape router, migrate to .yoke/ai
- `204a111` #21 refactor: move plan-architect and task-investigator into do/agents
- `1cdf226` #21 feat: add sub-agents mode body (plan + pause + execute pipeline)
- `5cd869b` #21 feat: add inline and team mode bodies, team report field
- `06f7a8f` #21 refactor: move task/plan to deprecated, drop from catalog counts
- `1c9a9d5` #21 refactor: repoint task/plan handoffs to /yoke:do
- `3486439` #21 docs: update README/CLAUDE for universal do, deprecated task/plan
- `10cdc66` #21 refactor: repoint task-investigator prose to do Plan phase
- `b1b8329` #21 docs: regenerate 16-skill catalog, actualize docs/do.md
