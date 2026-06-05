# Skill /gst

Shows development status in the repository: branch, uncommitted changes, commits relative to the
default branch, hot files, and a semantic summary. Collects data with a read-only script and formats
the report inline — no sub-agent.

## Input

Fires automatically on prompts like: "status", "gst", "git status", "what's going on",
"repo state", "show changes". No parameters.

```
/yoke:gst
```

## Steps

| Step | Name        | What happens                                                                                          |
| ---- | ----------- | ----------------------------------------------------------------------------------------------------- |
| 1    | **Collect** | `lib/gst-collect.sh` gathers branch, ahead/behind, counts, diff vs default, commits, hot files, stash |
| 2    | **Format**  | Orchestrator groups files by directory, applies relative timestamps, picks top-3 hot files            |
| 3    | **Summary** | Orchestrator writes a 2–3 sentence semantic summary from commits and changes                          |

## Output

A text report:

- **Branch** — current branch, upstream tracking, ahead/behind
- **Changes** — staged, unstaged, untracked with line counts
- **Files** — structured list with statuses (M/A/D/R)
- **Hot files** — top-3 by volume of changes
- **Commits** — up to 20 commits from merge-base with hash, message, time
- **Stash** — entries (if any)
- **Summary** — 2–3 sentences describing the work semantically

## Script

| Script               | Role                                 |
| -------------------- | ------------------------------------ |
| `lib/gst-collect.sh` | Collects git status data (read-only) |

## Example

```
/yoke:gst
```

Result: a text report on the repository state.

## Connections

Independent skill. Useful before `/gca` to verify changes and after `/do` to assess the result.
