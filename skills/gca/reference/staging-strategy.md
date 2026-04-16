# Staging strategy

Grouping files into atomic commits. Applied on standalone `/gca` invocations (outside yoke flow). `/do` uses its own pipeline model with per-task commits.

---

## Algorithm

### Step 1: Collection and classification

Collect all modified/new files via `git status --porcelain`. Classify each file:

| Group            | Criterion                                                                           | Commit type                 |
| ---------------- | ----------------------------------------------------------------------------------- | --------------------------- |
| `feature`        | Main task files (src/, components/, pages/, lib/, app/)                             | `feat` / `fix` / `refactor` |
| `test`           | Test files (`*.test.*`, `*.spec.*`, `__tests__/`, `*.cy.*`)                         | `test`                      |
| `docs`           | Documentation (`.md`, `docs/`, README, CHANGELOG)                                   | `docs`                      |
| `style`          | Formatting only (result of prettier/eslint --fix, no logical changes)               | `style`                     |
| `chore`          | Configs, dependencies (`package.json`, `*.config.*`, `.eslintrc`, CI)               | `chore`                     |
| `yoke-artifacts` | Yoke flow files (`docs/ai/**/*-task.md`, `*-plan.md`, `*-report.md`, `*-review.md`) | `docs`                      |

### Step 2: Determining atomic commits

- All files in one group -> one commit
- Files from different groups -> separate commits by group
- `feature` + `test` for the same feature -> combine into one commit (tests ship together with the code)
- `style` (linter output) -> always a separate commit
- `chore` (dependencies) -> always a separate commit
- `yoke-artifacts` -> a separate commit (or several, if they belong to different flow stages)

### Step 3: Commit order

1. `chore` (dependencies — base for everything else)
2. `feature`/`fix`/`refactor` + related `test` (main work)
3. `style` (formatting on top)
4. `docs` (documentation)
5. `yoke-artifacts` (planning artifacts — last)

### Step 4: Confirmation

Before executing, show the commit plan to the user:

```
Planned commits:
  1. chore: update eslint config
  2. #86 feat(86-black-jack-page): add game page with basic layout
  3. #86 test(86-black-jack-page): add unit tests for score calculation
  4. style: apply prettier formatting
  5. #86 docs(86-black-jack-page): add task definition

Proceed? [Y/n]
```

Show via AskUserQuestion with options:

- **Proceed** — run all planned commits
- **Edit** — user adjusts the grouping or messages
- **Cancel** — abort

---

## Safeguards

Exclude from staging:

- `.env`, `.env.*` — secrets
- Files containing credentials, tokens, keys
- Large binary files (images, videos, archives > 1MB)

When such files are detected, list them to the user and ask whether to include them in the commit.

Stage files by name (not `git add -A` and not `git add .`).
