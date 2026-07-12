# Skill /draft

The optional marking step between grill and do (ADR-0011). A do-shaped run — the same
inputs and the same finish machinery as `/do` — that marks instead of implementing: it
projects the agreed plan onto the code as Markup (`TODO(yoke):` Markers plus a
compilable skeleton) and opens a GitHub Draft PR for remote review. `/draft` never
pauses — the Draft PR is the pause. With it the flow becomes
**grill → draft → PR review → do**; grill → do stays the default path.

## Input

`$ARGUMENTS` — the same contract as `/do`, plus the iteration shapes:

| Input shape                                                          | Run               |
| -------------------------------------------------------------------- | ----------------- |
| nothing / a plain task description                                   | **fresh marking** |
| a single issue URL, a bare `<slug>`, or a `*-task.md` path           | **fresh marking** |
| a Draft PR URL, or a `<slug>` with `.yoke/ai/<slug>/<slug>-draft.md` | **iteration**     |

```
/yoke:draft https://github.com/org/repo/issues/42    # fresh marking from an issue
/yoke:draft https://github.com/org/repo/pull/57      # iteration against the Draft PR
```

## Flow

Fresh marking:

| Phase | Name               | What happens                                                                                                                                                                                                                   |
| ----- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0     | **Resolve**        | Detect fresh vs iteration, read the flow map, derive slug + ticket ID, enter a worktree per touched repo immediately — there is no confirmed-plan moment to defer it to.                                                       |
| 1     | **Plan**           | Dispatch `task-investigator` then `plan-architect` per `/do`'s Plan phase; write `.yoke/ai/<slug>/<slug>-plan.md`. No confirmation pause follows — the Draft PR review replaces the gate.                                      |
| 2     | **Mark**           | The orchestrator writes the Markup in-session: a `TODO(yoke):` Marker at every change site in existing files, a compilable skeleton for new structure. The build stays green; tests may be red; no implemented logic anywhere. |
| 3     | **Draft artifact** | Write `.yoke/ai/<slug>/<slug>-draft.md` — Draft PR URL(s), branch(es), touched-repo set, plan pointer.                                                                                                                         |
| 4     | **Finish**         | `/do`'s finish contract with `--draft` forced on the pr call: push, one Draft PR per repo, ticket comment, one STAGE_COMPLETE notify carrying the Draft PR link(s).                                                            |

Iteration — a re-run against an existing Draft, still without pauses:

1. Read the Draft artifact and the plan; enter the recorded branch(es).
2. Fetch the PR comments — inline review threads and top-level conversation.
3. Redraw the Markup in the same branch — comments outrank the existing Markers and the
   plan; the build stays green; the Draft PR updates in place, never a second PR.
4. Reply in every inline review thread with what changed and where; thread resolution
   stays the user's.
5. Re-fire the STAGE_COMPLETE notify.

Any number of rounds.

## The draft → ready lifecycle

One PR carries the whole history from Markup to ready, across the two skills:

| Step | Actor                              | What happens                                                                                                                                                                                             |
| ---- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | `/draft`                           | Marks the code and opens the Draft PR (one per touched repo).                                                                                                                                            |
| 2    | user                               | Reviews the Draft PR on GitHub and comments; re-runs `/draft` to re-mark per the comments — any number of rounds.                                                                                        |
| 3    | `/do <draft-PR-URL>` (or `<slug>`) | Draft execution: implements per comments > Markers > plan, deletes every Marker (the grep gate blocks the flip on any leftover), replies in threads, flips the **same** PR to ready — never a second PR. |

`/draft` never flips the PR to ready and never merges — the flip belongs to `/do` Draft
execution, the merge to `/merge`.

## Output

**Output:** Draft PR link(s), Draft artifact at `.yoke/ai/<slug>/<slug>-draft.md`, plan at `.yoke/ai/<slug>/<slug>-plan.md`, ticket comment, STAGE_COMPLETE notify

File `.yoke/ai/<slug>/<slug>-draft.md` — the record a fresh `/do <slug>` session uses to find the Draft:

- **Draft PR URL(s)** — one per touched repo
- **Branch(es)** — the Markup branch in each touched repo
- **Touched-repo set** — the repos from the flow map this Draft marks
- **Plan pointer** — the path to `<slug>-plan.md`

## Example

```
/yoke:draft https://github.com/org/repo/issues/42
```

## Connections

```
/grill → /yoke:draft → PR review → /yoke:do → ready PR
```

`/draft` reuses `/do`'s finish contract (worktree, push, PR per repo, ticket comment,
notify) and the pr skill's mechanics with `--draft` forced on. Downstream, `/do`
consumes the Draft via its Draft execution mode; `/merge` runs only after the PR is
ready and approved. The Markup contract — Marker format, skeleton rules, the grep-gate
scope — lives in `skills/draft/reference/markup-format.md`.
