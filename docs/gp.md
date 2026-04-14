# Skill /gp

Git push with pre-push checks and a post-push report. Inspects the repository state, handles edge
cases (detached HEAD, no remote, uncommitted changes, default branch protection), pushes to the remote,
and prints a report with pushed commits, diff stat, branch link, and PR status.

## Input

`$ARGUMENTS` (optional) — push flags (`--force-with-lease`).

```
/sp:gp
/sp:gp --force-with-lease
```

## Phases

| Phase | Name          | What happens                                                                      |
| ----- | ------------- | --------------------------------------------------------------------------------- |
| 1     | **Pre-check** | Sub-agent collects data: branch, upstream, unpushed commits, uncommitted, gh auth |
| 2     | **Decide**    | Orchestrator handles blocking errors and interactive decisions                    |
| 3     | **Push**      | Sub-agent runs push, collects pushed commits, diff stat, branch URL, PR           |
| 4     | **Report**    | Orchestrator shows the report to the user                                         |

## Checks (Phase 2)

Strict order — from blocking to interactive:

| Check               | Condition                                  | Action                                  |
| ------------------- | ------------------------------------------ | --------------------------------------- |
| Detached HEAD       | Branch not determined                      | Error: check out a branch               |
| gh CLI              | Not installed or not authenticated         | Error with instructions                 |
| No remote           | `origin` missing                           | Error: add a remote                     |
| Nothing to push     | 0 unpushed, upstream exists, 0 uncommitted | Message and exit                        |
| Default branch      | Push to main/master                        | AskUserQuestion: continue?              |
| Uncommitted changes | Uncommitted files present                  | AskUserQuestion: commit / push / cancel |

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
- **PR** — existing PR (URL, title) or "PR not found"

## Sub-agents

| Agent             | Model | Role                                               |
| ----------------- | ----- | -------------------------------------------------- |
| `git-pre-checker` | haiku | Collects data before push (read-only)              |
| `git-pusher`      | haiku | Runs the push, collects the report (only mutation) |

## Example

```
/sp:gp
```

Result: push the current branch to origin, report with commits and stats.

## Connections

Typical flow: `/task` → `/plan` → `/do` → `/review` → `/gca` → `/gp` → `/pr`.
Also works standalone — for any push outside SP flow.
