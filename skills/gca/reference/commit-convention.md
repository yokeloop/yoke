# Commit Convention

Unified commit format for all SP skills and standalone use.

---

## Format

```
[ticket] <type>(<slug>): <description>
```

- **Language**: ALWAYS English. No exceptions. Even if the user writes in another language, even if code contains comments in another language.
- **ticket**: placed first. Determined by cascade (see Ticket ID section). Omit if absent.
- **type**: determined by the nature of changes (see Type table).
- **slug**: determined by context (see Slug section).
- **description**: one sentence, imperative mood, English. Describes what was done, not how.

---

## Ticket ID

Cascade of priorities:

### From arguments

User may pass ticket ID or URL directly.

| Input                                     | Ticket ID  |
| ----------------------------------------- | ---------- |
| `86` or `#86`                             | `#86`      |
| `R2-50`                                   | `R2-50`    |
| `PROJ-123`                                | `PROJ-123` |
| `https://github.com/.../issues/86`        | `#86`      |
| URL YouTrack containing `/issue/PROJ-123` | `PROJ-123` |

### From branch name

| Branch name             | Regex          | Ticket ID  |
| ----------------------- | -------------- | ---------- |
| `86-feature-name`       | `^(\d+)-`      | `#86`      |
| `feature/86-name`       | `\/(\d+)-`     | `#86`      |
| `R2-50-feature`         | `(R\d+-\d+)`   | `R2-50`    |
| `fix/R2-50-name`        | `(R\d+-\d+)`   | `R2-50`    |
| `PROJ-123-feature`      | `([A-Z]+-\d+)` | `PROJ-123` |
| `main`, `develop`, etc. | --             | not found  |

### From SP flow

If executing within SP flow (`/task` -> `/plan` -> `/do` -> `/review`), extract ticket ID from slug:

| Slug pattern                               | Ticket ID | Example |
| ------------------------------------------ | --------- | ------- |
| Starts with number: `86-black-jack-page`   | `#86`     | `#86`   |
| Starts with `R\d+-\d+`: `R2-50-user-id-db` | `R2-50`   | `R2-50` |
| No ID: `fix-navbar-overflow`               | none      | omit    |

### Ask user

If ticket not found by any method, ask via AskUserQuestion:

- **No ticket** -- commit without ticket
- **Enter number** -- user provides ticket ID

---

## Type

| Type       | When                                     |
| ---------- | ---------------------------------------- |
| `feat`     | New functionality                        |
| `fix`      | Bug fix                                  |
| `refactor` | Refactoring without behavior change      |
| `docs`     | Documentation only                       |
| `test`     | Tests only                               |
| `chore`    | Build, CI, dependencies, configs         |
| `style`    | Formatting only (prettier/eslint result) |
| `perf`     | Performance optimization                 |

---

## Slug

Determined by context:

### Inside SP flow

Slug = value formed during `/task` creation (e.g. `86-black-jack-page` from `docs/ai/86-black-jack-page/`). Detect by presence of active task/plan file in `docs/ai/` or by passed path.

### Outside SP flow (standalone /gca)

Slug = current branch name stripped of prefix (`feature/`, `fix/`, `hotfix/`, `bugfix/`, `release/`). If branch is `main`, `master`, or `develop` -- omit slug.

---

## Examples

```
#86 feat(86-black-jack-page): add game page with basic layout
#86 fix(86-black-jack-page): correct score calculation on ace cards
R2-50 refactor(auth-redesign): extract token refresh into separate service
docs(86-black-jack-page): update task file with clarified requirements
chore: update dependencies
style: apply prettier formatting
```

---

## SP Artifact Types

Special commit types for SP flow artifacts:

```
docs(<slug>): add task definition           # after /task
docs(<slug>): add implementation plan       # after /plan
docs(<slug>): add execution report          # after /do
docs(<slug>): add review report             # after /review
```

---

## Pipeline Stage Types (for /do)

| Stage          | Type       | Example                                                 |
| -------------- | ---------- | ------------------------------------------------------- |
| Task: feature  | `feat`     | `#86 feat(86-black-jack-page): add SSE endpoint`        |
| Task: tests    | `test`     | `R2-50 test(R2-50-user-id-db): add unit tests`          |
| Task: validate | `chore`    | `#86 chore(86-black-jack-page): add validation`         |
| Polish         | `refactor` | `#86 refactor(86-black-jack-page): simplify components` |
| Validate fix   | `fix`      | `#86 fix(86-black-jack-page): fix lint errors`          |
| Documentation  | `docs`     | `#86 docs(86-black-jack-page): update docs`             |
| Format         | `chore`    | `#86 chore(86-black-jack-page): format code`            |

---

## Rules

- One commit per logical change. Do not combine unrelated changes.
- Ticket ID always first in message (if present).
- Do NOT use `wip`, `temp`, `misc`.
- Do NOT commit secrets and credentials.
- Do NOT add `Co-Authored-By`, `Signed-off-by`, or any trailer lines.
- Commit message: concise, specific, imperative mood, English.
- If task contains both implementation and tests -- use `feat` (tests go with feature).
- If task is tests only -- use `test`.
