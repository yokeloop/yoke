# Skill /gp

Git push with pre-push checks and a post-push report. Inspects repository state, handles edge
cases (detached HEAD, no remote, nothing to push), pushes to the remote, and prints a report with
pushed commits, diff stat, branch link, and PR status. Runs autonomously — no confirmation prompts.

## Input

`$ARGUMENTS` (optional) — push flags (`--force-with-lease`).

```
/yoke:gp
/yoke:gp --force-with-lease
```

## Steps

| Step | Name          | What happens                                                                     |
| ---- | ------------- | -------------------------------------------------------------------------------- |
| 1    | **Pre-check** | `lib/gp-precheck.sh` collects state: branch, upstream, unpushed, uncommitted, gh |
| 2    | **Decide**    | Orchestrator: blocking errors and PUSH_MODE — no prompts                         |
| 3    | **Push**      | `lib/gp-push.sh` runs push, collects pushed commits, diff stat, URL, PR          |
| 4    | **Report**    | Orchestrator prints the report and suggests `/yoke:pr`                           |

## Checks (Step 2)

| Check           | Condition                          | Action                            |
| --------------- | ---------------------------------- | --------------------------------- |
| Detached HEAD   | Branch not determined              | Error: check out a branch, stop   |
| No remote       | `origin` missing                   | Error: add a remote, stop         |
| Nothing to push | 0 unpushed and upstream exists     | Message and stop                  |
| gh CLI          | Not installed or not authenticated | Non-blocking: skip PR/URL info    |
| Uncommitted     | Uncommitted files present          | Non-blocking: note them in report |

## Push modes

| Mode             | When                        | Command                       |
| ---------------- | --------------------------- | ----------------------------- |
| normal           | Upstream exists             | `git push`                    |
| set-upstream     | New branch without upstream | `git push -u origin <branch>` |
| force-with-lease | `--force-with-lease` passed | `git push --force-with-lease` |

## Output

A text report:

- **Pushed commits** — up to 20 commits with hash and message
- **Stats** — files changed, insertions, deletions
- **Link** — branch URL on GitHub
- **PR** — existing PR (URL, title) or a suggestion to create one
- **Uncommitted** — files not pushed (if any)

## Scripts

| Script               | Role                                               |
| -------------------- | -------------------------------------------------- |
| `lib/gp-precheck.sh` | Collects state before push (read-only)             |
| `lib/gp-push.sh`     | Runs the push, collects the report (only mutation) |

## Example

```
/yoke:gp
```

Result: pushes the current branch to origin and prints a report with commits and stats.

## Connections

Typical flow: `/task` → `/plan` → `/do` → `/review` → `/gca` → `/gp` → `/pr`.
Also works standalone — for any push outside yoke flow.
