# Staging strategy

Grouping files into atomic commits. Applied on standalone `/gca` invocations (outside yoke flow). `/do` uses its own pipeline model with per-task commits.

---

## Algorithm

### Step 1: Collection and classification

Collect all modified/new files via `git status --porcelain` (untracked files appear as `??`). Classify each file:

| Group            | Criterion                                                                | Commit type                 |
| ---------------- | ------------------------------------------------------------------------ | --------------------------- |
| `feature`        | Main task files (src/, components/, pages/, lib/, app/)                  | `feat` / `fix` / `refactor` |
| `test`           | Test files (`*.test.*`, `*.spec.*`, `__tests__/`, `*.cy.*`)              | `test`                      |
| `docs`           | Documentation (`.md`, `docs/`, README, CHANGELOG)                        | `docs`                      |
| `style`          | Formatting only (result of project formatter/linter, no logical changes) | `style`                     |
| `chore`          | Configs, dependencies (`package.json`, `*.config.*`, `.eslintrc`, CI)    | `chore`                     |
| `yoke-artifacts` | Yoke flow files under `docs/ai/**`                                       | `docs`                      |

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

### Step 4: Execute

Standalone runs autonomously — no confirmation. Execute the planned commits in order and report each one: hash, message, files.

---

## Safeguards

Exclude from staging:

- `.env`, `.env.*` — secrets
- Files containing credentials, tokens, keys
- Large binary files (images, videos, archives > 1MB)

When you detect such files, exclude them and list them in the final report. Do not ask.

Stage files by name (not `git add -A` and not `git add .`).
