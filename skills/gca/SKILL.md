---
name: gca
description: >-
  Git staging and commit with smart file grouping and SP flow awareness.
  This skill should be used when the user asks to commit changes, stage files,
  make a git commit, "commit this", "save my work", "gca", "закоммить",
  "сделай коммит", "закоммитить изменения", or when any other skill needs
  to commit results. Also use after completing /task, /plan, /do, /review
  to commit artifacts.
---

# Git Commit with Smart Staging

Orchestrator for git commits: detect context, classify files, group into atomic commits, format messages by convention.

---

## Step 1 -- Collect Context

Run in parallel:

```bash
git status --porcelain
```

```bash
git diff HEAD --stat
```

```bash
git branch --show-current
```

```bash
git ls-files --others --exclude-standard
```

If no changes (no staged, unstaged, or untracked) -- inform user and stop.

---

## Step 2 -- Detect Context

Determine whether running inside SP flow or standalone.

### SP flow detection

Check if `$ARGUMENTS` contains a path to `docs/ai/` or a slug. Check if `docs/ai/*/` directories exist with recent artifacts. If found:

- `MODE = sp-flow`
- `SLUG` = from path or directory name
- `TICKET_ID` = extracted from slug per `reference/commit-convention.md`

### Standalone detection

If no SP flow context:

- `MODE = standalone`
- `SLUG` = current branch name stripped of prefix (`feature/`, `fix/`, `hotfix/`, `bugfix/`, `release/`). If branch is `main`/`master`/`develop` -- omit slug.

---

## Step 3 -- Determine Ticket ID

Follow the cascade from `reference/commit-convention.md`:

1. **From `$ARGUMENTS`** -- if user passed ticket ID or URL, extract it
2. **From slug** (SP flow) -- extract from slug pattern
3. **From branch name** (standalone) -- extract by regex patterns
4. **Ask user** -- via AskUserQuestion with options: "No ticket" / "Enter number"

---

## Step 4 -- Classify and Stage

### SP flow mode

If called after a specific skill (task/plan/do/review), commit only the artifact of that stage. One commit per artifact:

```
[ticket] docs(<slug>): add task definition
[ticket] docs(<slug>): add implementation plan
[ticket] docs(<slug>): add execution report
[ticket] docs(<slug>): add review report
```

### Standalone mode

Read `reference/staging-strategy.md` and apply:

1. Collect all changed/new files
2. Classify into groups (feature, test, docs, style, chore, sp-artifacts)
3. Determine atomic commits per group
4. Apply protections (skip .env, credentials, large binaries -- warn user)
5. Show commit plan to user for confirmation via AskUserQuestion

---

## Step 5 -- Format Commit Messages

Read `reference/commit-convention.md`. For each planned commit:

- Format: `[ticket] <type>(<slug>): <description>`
- Language: ALWAYS English
- Ticket ID first (if present)
- Description: one sentence, imperative mood

---

## Step 6 -- Execute Commits

For each planned commit:

1. `git add` specific files by name (never `git add -A`)
2. `git commit -m "<message>"` -- no Co-Authored-By, no trailers
3. Show result: hash, message, file list

---

## Rules

- All commits in English. No exceptions.
- One commit per logical change.
- Ticket ID always first in message (if present).
- Stage files by name, not `git add -A`.
- Do NOT commit secrets, credentials, large binaries.
- Do NOT use `wip`, `temp`, `misc`.
- Do NOT add Co-Authored-By, Signed-off-by, or any trailer lines.
- Confirmation required before executing multiple commits in standalone mode.

## Reference Files

- **`reference/commit-convention.md`** -- commit message format, ticket ID extraction, type table, slug logic
- **`reference/staging-strategy.md`** -- file classification, grouping algorithm, commit ordering (standalone mode only)
