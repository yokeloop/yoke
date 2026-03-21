# Staging Strategy

Smart file grouping for atomic commits. Applies to standalone `/gca` invocation by user (outside SP flow). `/do` has its own per-task pipeline -- it does NOT use this strategy.

---

## Algorithm

### Step 1: Collect and Classify

Collect all changed/new files via `git status --porcelain`. Classify each file into one group:

| Group          | Criteria                                                                          | Commit type                 |
| -------------- | --------------------------------------------------------------------------------- | --------------------------- |
| `feature`      | Files related to main task (src/, components/, pages/, lib/, app/)                | `feat` / `fix` / `refactor` |
| `test`         | Test files (`*.test.*`, `*.spec.*`, `__tests__/`, `*.cy.*`)                       | `test`                      |
| `docs`         | Documentation (`.md`, `docs/`, README, CHANGELOG)                                 | `docs`                      |
| `style`        | Formatting only (result of prettier/eslint --fix, no logic changes)               | `style`                     |
| `chore`        | Configs, dependencies (`package.json`, `*.config.*`, `.eslintrc`, CI)             | `chore`                     |
| `sp-artifacts` | SP flow files (`docs/ai/**/*-task.md`, `*-plan.md`, `*-report.md`, `*-review.md`) | `docs`                      |

### Step 2: Determine Atomic Commits

- All files belong to one group -> one commit
- Files from different groups -> split into separate commits per group
- `feature` + `test` for the same feature -> may combine into one commit (tests ship with code)
- `style` (linter result) -> always separate commit
- `chore` (dependencies) -> always separate commit
- `sp-artifacts` -> separate commit (or commits if different flow stages)

### Step 3: Commit Order

1. `chore` (dependencies -- foundation for everything else)
2. `feature`/`fix`/`refactor` + related `test` (main work)
3. `style` (formatting on top)
4. `docs` (documentation)
5. `sp-artifacts` (planning artifacts -- last)

### Step 4: Confirmation

Before executing, show the commit plan to user:

```
Planned commits:
  1. chore: update eslint config
  2. #86 feat(86-black-jack-page): add game page with basic layout
  3. #86 test(86-black-jack-page): add unit tests for score calculation
  4. style: apply prettier formatting
  5. #86 docs(86-black-jack-page): add task definition

Proceed? [Y/n]
```

Present via AskUserQuestion with options:

- **Proceed** -- execute all planned commits
- **Edit** -- user adjusts grouping or messages
- **Cancel** -- abort

---

## Protections

Do NOT stage:

- `.env`, `.env.*` -- secrets
- Files with credentials, tokens, keys
- Large binary files (images, videos, archives > 1MB)

When detected -- warn user before adding. List the files and ask whether to include.

Stage files by name (not `git add -A` or `git add .`).
