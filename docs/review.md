# Skill /review

Finds problems in code, fixes selected issues, and produces a report. Analyzes changes
against origin/main, presents issues for interactive fix-scope selection, applies fixes
via sub-agents, and writes an issues-driven review report.

## Input

`$ARGUMENTS` — task slug or path to a task file. Without an argument, the skill resolves the slug
from the branch or the latest directory under `.yoke/ai/`.

```
/yoke:review 86-black-jack-page
/yoke:review .yoke/ai/86-black-jack-page/86-black-jack-page-task.md
/yoke:review
```

## Phases

| Phase | Name         | What happens                                                                                                         |
| ----- | ------------ | -------------------------------------------------------------------------------------------------------------------- |
| 1     | **Parse**    | Resolve SLUG and TICKET_ID from arguments, task file path, or branch name; collect KNOWN_ISSUES from prior artifacts |
| 2     | **Analyze**  | Dispatch `code-reviewer` sub-agent; receive SUMMARY, ISSUES, ISSUES_COUNT                                            |
| 3     | **Select**   | Show all issues to the user; choose fix scope via AskUserQuestion (Critical+Important / Critical only / All / Skip)  |
| 4     | **Fix**      | Dispatch `single-fix-agent` per file group; then `validator` + `formatter` from /do in parallel; commit fixes        |
| 5     | **Finalize** | Write review report; commit artifact; post skipped issues as PR comments if a PR exists                              |
| 6     | **Complete** | Send notification; report found/fixed/skipped counts; ask what to do next (push / PR / finish)                       |

## Output

File `.yoke/ai/<slug>/<slug>-review.md` with the following sections:

**Summary** (7 sub-sections):

- **Context and goal** — what was done and why
- **Key code areas for review** — files/functions needing close attention
- **Complex decisions** — architectural trade-offs with rationale
- **Questions for the reviewer** — items requiring discussion
- **Risks and impact** — potential problems, regressions, edge cases
- **Tests and manual checks** — coverage and verification scenarios
- **Out of scope** — what the PR intentionally excludes

**Issues-driven tables**:

- **Commits** — hash + description from `git log origin/main..HEAD`
- **Changed Files** — file paths with `+/-` stats
- **Issues Found** — severity / score / category / file:line / description, sorted by score descending (Critical 80-100, Important 50-79, Minor 0-49)
- **Fixed Issues** — issue description linked to fix commit hash
- **Skipped Issues** — issue description with reason (user choice or scope exclusion)
- **Recommendations** — follow-up actions based on skipped issues and overall analysis

## Sub-agents

| Agent              | Model  | Role                                                                                 |
| ------------------ | ------ | ------------------------------------------------------------------------------------ |
| `code-reviewer`    | sonnet | Collects git data, analyzes diff across 7 dimensions, returns SUMMARY + ISSUES       |
| `single-fix-agent` | —      | Applies a group of fixes to one or more files; returns FIXED, SKIPPED, FILES_CHANGED |
| `validator`        | —      | Reused from /do; validates changed files and commits fixes when needed               |
| `formatter`        | —      | Reused from /do; formats changed files and commits fixes when needed                 |

## Example

```
/yoke:review 86-black-jack-page
```

Result: `.yoke/ai/86-black-jack-page/86-black-jack-page-review.md`

## Connections

```
/yoke:do → /yoke:review
```

`/review` is a standalone code-analysis tool: it audits the `/do` report and the code changes on demand. In the main flow the user reviews the PR itself on GitHub.
