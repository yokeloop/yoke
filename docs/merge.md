# Skill /merge

The user-triggered finisher. The flow ends at a pull request (ADR-0006): `/do` drives every
run to a ready PR and stops. `/merge` executes the post-PR tail declared in `.yoke/flow.md` —
merge, cascade, deploy/release, ticket transition, worktree cleanup — turning the user's one
merge decision into one command. Never auto-runs: it fires only on the explicit word, and the
merge decision stays the user's.

**Output:** merged PR(s), cascade merges, deploy/release runs, ticket transition, cleaned worktrees

## Input

`$ARGUMENTS` (optional) — PR URL(s) or a `<slug>`. Empty means the current branch/worktree's
task: the skill resolves its open PR(s) via `gh` (`gh pr view`, `gh pr list --head <branch>`).

```
/yoke:merge
/yoke:merge <slug>
/yoke:merge https://github.com/org/repo/pull/42
```

Before acting the skill reports what will be merged. More than one PR — or any ambiguity
(unclear branch, several open PRs, an unclear target) — is one AskUserQuestion with a
recommended "Merge all listed" option first. A single unambiguous PR needs no question.

## Steps

Each step reads its guard from the flow map (`lib/flow-read.sh`) and is **skipped silently when
the flow map does not declare its data** — omission means "apply the default", never "fail".

| Step | Name                  | What happens                                                                 | Skip guard                              |
| ---- | --------------------- | ---------------------------------------------------------------------------- | --------------------------------------- |
| 1    | **Merge PR(s)**       | `gh pr merge <n> --merge --delete-branch` for each resolved PR               | libraries have no PR — nothing to merge |
| 2    | **Cascade**           | Advance the branch cascade (e.g. master → staging → develop) per step        | `CASCADE_STEPS = none`                  |
| 3    | **Deploy / release**  | Run each `DEPLOY_COMMANDS` command verbatim, in order, nothing inferred      | `DEPLOY_COMMANDS = none`                |
| 4    | **Ticket transition** | Move the ticket to `TRACKER_TARGET_STATE`, add a `merged: <PR URLs>` comment | `TRACKER = none`                        |
| 5    | **Worktree cleanup**  | Remove the task's worktree(s); never remove one with uncommitted changes     | the task used no worktree               |
| 6    | **Return to default** | Land the main checkout on the default branch and sync the merged state       | —                                       |

On a cascade conflict the skill stops, reports, and never forces — no strategy override, no
`--force`, no history rewrite. Multi-repo: merge every one of the task's PRs, then repeat
cleanup and return per repo from the flow map's `REPOS` list.

## Notify

On finish, one STAGE_COMPLETE notification carries what was merged and deployed:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill merge \
  --title "<slug>: merged" --body "<merged PR(s) + cascade + deploy/release summary>"
```

## Example

```
/yoke:merge
```

Result: the current task's PR merged, the cascade advanced, declared deploy/release commands
run, the ticket transitioned, and the worktree cleaned up — the checkout back on the default
branch.

## Connections

```
/yoke:do → PR → (user approves on GitHub) → /yoke:merge
```

`/do` finishes at the PR; `/merge` runs the tail once the user decides to ship. It routes to
`reference/merge-procedure.md` for the full mechanics and reads `lib/flow-read.sh` for the
flow map. Boundaries mirror `/do`: git authorization comes from the invocation itself,
artifacts stay under `.yoke/`, and no step improvises history-rewriting recovery.
