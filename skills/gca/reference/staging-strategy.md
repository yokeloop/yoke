# Staging strategy

Grouping files into atomic commits. Applied on standalone `/gca` invocations (outside yoke flow). `/do` uses its own pipeline model with per-task commits.

---

## Algorithm

### Step 1: Collection and classification

Collect **all** modified/new files via `git status --porcelain` (untracked files appear as `??`) — `git status` is the single source of truth. Every entry is in scope regardless of who produced it (this session, another session, or the user editing by hand); git has no per-session authorship for unstaged changes, so do not invent one. Classify each file:

| Group            | Criterion                                                                | Commit type                 |
| ---------------- | ------------------------------------------------------------------------ | --------------------------- |
| `feature`        | Main task files (src/, components/, pages/, lib/, app/)                  | `feat` / `fix` / `refactor` |
| `test`           | Test files (`*.test.*`, `*.spec.*`, `__tests__/`, `*.cy.*`)              | `test`                      |
| `docs`           | Documentation (`.md`, `docs/`, README, CHANGELOG)                        | `docs`                      |
| `style`          | Formatting only (result of project formatter/linter, no logical changes) | `style`                     |
| `chore`          | Configs, dependencies (`package.json`, `*.config.*`, `.eslintrc`, CI)    | `chore`                     |
| `yoke-artifacts` | Yoke flow files under `.yoke/ai/**`                                      | `docs`                      |

When a file matches several rows, tie-break by precedence: `yoke-artifacts` > `test` > `style` > `chore` > `docs` > `feature`. `perf` and `style` are content-judgement types, not path-derivable — apply them only when the diff clearly warrants it.

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

## Scope

Standalone gca commits the **entire working tree**. Never exclude a file because it "wasn't this session's edit," because another session changed it, or because the change's context is unknown — that is precisely what makes the user re-run gca. Provenance is irrelevant to staging.

## Safeguards

Exclusions are narrow and apply only to **untracked** (`??`) files that are genuine footguns:

- `.env`, `.env.*`
- raw secret/key files: `*.pem`, `*.key`, `id_rsa`, `*.p12`, files plainly named as credentials
- any binary over 1MB (e.g. images, videos, archives)

Tracked files are always committed — git-crypt-managed files included, since the clean filter encrypts them on commit, so committing them is safe and intended. Apply the name-based judgement above to **untracked** files only; never inspect a tracked file's name or contents to decide exclusion.

When you exclude an untracked footgun, do not ask — commit everything else and list the excluded files in the final report.

Stage files by name (not `git add -A` and not `git add .`).
