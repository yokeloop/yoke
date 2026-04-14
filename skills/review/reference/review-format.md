# Review Report Format

Format of the output file `<SLUG>-review.md`. The review-report-writer agent writes this file.

---

## Template

```markdown
# Code Review: <SLUG>

## Summary

### Context and goal

<1-3 sentences: what was done and why>

### Key code areas for review

1. **`src/path/file.ts:fn()`** — <why it matters>

### Complex decisions

1. **<What>** (`src/path/file.ts:42`)
   <Why it is done this way. Trade-offs.>

### Questions for the reviewer

1. <Concrete question on architecture, contracts, performance, security, or readability>

### Risks and impact

- <Risk>: <what to watch out for>

### Tests and manual checks

**Auto-tests:**

- <what should be covered>

**Manual scenarios:**

1. <Step> → <expected result>

### Out of scope

- <what the PR intentionally excludes>

## Commits

| Hash    | Description     |
| ------- | --------------- |
| abc1234 | feat(slug): ... |

## Changed Files

| File             | +/-     | Description      |
| ---------------- | ------- | ---------------- |
| src/path/file.ts | +42/-10 | <what changed>   |

## Issues Found

| Severity  | Score | Category    | File:line            | Description                  |
| --------- | ----- | ----------- | -------------------- | ---------------------------- |
| Critical  | 90    | security    | src/auth/login.ts:42 | SQL injection in query       |
| Important | 65    | performance | src/api/list.ts:15   | N+1 query in loop            |
| Minor     | 30    | style       | src/utils/fmt.ts:8   | Unused import                |

> No issues — replace the table with text: **Code is clean.**

## Fixed Issues

| Issue                       | Commit    | Description                  |
| --------------------------- | --------- | ---------------------------- |
| SQL injection in login.ts:42 | `def5678` | Parameterized query          |
| N+1 query in list.ts:15     | `ghi9012` | Batch load via Promise       |

> No fixes — replace the table with text: **All issues fixed.**

## Skipped Issues

| Issue          | Reason                           |
| -------------- | -------------------------------- |
| Unused import  | Stylistic, out of PR scope       |

> No skipped — replace the table with text: **All found issues were fixed.**

## Recommendations

- <Recommendation for PR review: what to watch out for when merging>
```

---

## Rules

- **Summary** — 7 dimensions: context and goal, key areas, complex decisions, questions for the reviewer, risks, tests, out of scope.
- **Issues Found** — sort by Score descending. Severity: `Critical` / `Important` / `Minor`.
- **Fixed Issues** and **Skipped Issues** — show if Issues Found contains entries.
- Replace empty tables with the placeholders from the `>` blocks above.
- Active voice, concrete phrasing, no filler words.
