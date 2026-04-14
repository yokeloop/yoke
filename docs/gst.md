# Skill /gst

Shows development status in the repository: branch, uncommitted changes, commits relative to the
default branch, hot files, and a semantic summary. Delegates data collection to a sub-agent.

## Input

Fires automatically on prompts like: "status", "gst", "git status", "what's going on",
"repo state", "show changes". No parameters.

```
/sp:gst
```

## Phases

| Phase | Name                 | What happens                                                                          |
| ----- | -------------------- | ------------------------------------------------------------------------------------- |
| 1     | **Launch agent**     | Delegate data collection to sub-agent `git-data-collector`                            |
| 2     | **Collect data**     | Current branch, ahead/behind, staged/unstaged/untracked, diff vs default branch       |
| 3     | **Format output**    | Group files by directory, relative timestamps, hot files (top-3)                      |

## Output

A text report:

- **Branch** — current branch, upstream tracking, ahead/behind
- **Changes** — staged, unstaged, untracked with line counts
- **Files** — structured list with statuses (M/A/D/R)
- **Hot files** — top-3 by volume of changes
- **Commits** — up to 20 commits from merge-base with hash, message, time
- **Stash** — entries (if any)
- **Summary** — 2–3 sentences describing the work semantically

## Sub-agents

| Agent                | Model  | Role                                                   |
| -------------------- | ------ | ------------------------------------------------------ |
| `git-data-collector` | haiku  | Collects git data (read-only), formats the report      |

## Example

```
/sp:gst
```

Result: a text report on the repository state.

## Connections

Independent skill. Useful before `/gca` (verify changes) and after `/do` (assess the result).
