# Commit Convention

Commit format for yoke skills and standalone invocations.

---

## Format

```
TICKET type(SLUG): description
```

Example: `#86 feat(86-black-jack-page): add game page`

- **Language**: ALWAYS English. No exceptions.
- **TICKET**: first in the message, separated by a space (NO colon after the ticket). Determined by cascade (see the Ticket ID section). If no ticket — omit it together with the space.
- **type**: determined by the nature of the changes (see the type table).
- **SLUG**: in parentheses after type. Determined by context (see the Slug section). If no slug — omit the parentheses: `type: description`.
- **description**: one sentence, imperative mood. Describes what was done, not how.

### Anti-patterns

```
# WRONG:
R2-220: fix: restrict analytics          # colon after ticket, no slug
R2-220: fix(slug): restrict analytics    # colon after ticket
fix: restrict analytics [R2-220]         # ticket at the end

# CORRECT:
R2-220 fix(R2-220-fix-doubled-stats): restrict analytics
```

---

## Ticket ID

Priority cascade:

### From arguments

The user passes a ticket ID or URL.

| Input                               | Ticket ID  |
| ----------------------------------- | ---------- |
| `86` or `#86`                       | `#86`      |
| `R2-50`                             | `R2-50`    |
| `PROJ-123`                          | `PROJ-123` |
| `https://github.com/.../issues/86`  | `#86`      |
| YouTrack URL with `/issue/PROJ-123` | `PROJ-123` |

### From the branch name

| Branch name             | Regex          | Ticket ID  |
| ----------------------- | -------------- | ---------- |
| `86-feature-name`       | `^(\d+)-`      | `#86`      |
| `feature/86-name`       | `\/(\d+)-`     | `#86`      |
| `R2-50-feature`         | `(R\d+-\d+)`   | `R2-50`    |
| `fix/R2-50-name`        | `(R\d+-\d+)`   | `R2-50`    |
| `PROJ-123-feature`      | `([A-Z]+-\d+)` | `PROJ-123` |
| `main`, `develop`, etc. | --             | not found  |

### From yoke flow

Within yoke flow (`/task` -> `/plan` -> `/do` -> `/review`) the ticket ID is extracted from the slug:

| Slug pattern                               | Ticket ID | Example |
| ------------------------------------------ | --------- | ------- |
| Starts with a number: `86-black-jack-page` | `#86`     | `#86`   |
| Starts with `R\d+-\d+`: `R2-50-user-id-db` | `R2-50`   | `R2-50` |
| Without ID: `fix-navbar-overflow`          | none      | omit    |

### Ask the user

If the cascade did not determine a ticket — ask via AskUserQuestion:

- **No ticket** — commit without a link
- **Enter number** — user supplies the ticket ID

---

## Types

| Type       | When                                                                                          |
| ---------- | --------------------------------------------------------------------------------------------- |
| `feat`     | New functionality                                                                             |
| `fix`      | Bug fix                                                                                       |
| `refactor` | Refactoring without behavior change                                                           |
| `docs`     | Documentation only                                                                            |
| `test`     | Tests only                                                                                    |
| `chore`    | Build, CI, dependencies, configs                                                              |
| `style`    | Formatting only (result of project formatter/linter, e.g. prettier, eslint, black, cargo fmt) |
| `perf`     | Performance optimization                                                                      |

---

## Slug

Determined by context:

### Within yoke flow

Slug = task directory name (e.g. `86-black-jack-page` from `docs/ai/86-black-jack-page/`). Source: active task/plan file in `docs/ai/` or the passed path.

### Outside yoke flow (standalone /gca)

Slug = current branch name without prefix (`feature/`, `fix/`, `hotfix/`, `bugfix/`, `release/`). If the branch is `main`, `master` or `develop` — omit the slug.

---

## Examples

```
#86 feat(86-black-jack-page): add game page with basic layout
#86 fix(86-black-jack-page): correct score calculation on ace cards
R2-50 refactor(auth-redesign): extract token refresh into separate service
docs(86-black-jack-page): update task file with clarified requirements
chore: update dependencies
style: apply code formatting
```

---

## Types for yoke artifacts

Commits for yoke flow artifacts (format `TICKET docs(SLUG): description`):

```
#86 docs(86-black-jack-page): add task definition           # after /task
#86 docs(86-black-jack-page): add implementation plan       # after /plan
#86 docs(86-black-jack-page): add execution report          # after /do
#86 docs(86-black-jack-page): add review report             # after /review
```

---

## Types by pipeline stage (/do)

| Stage                        | Type       | Example                                                 |
| ---------------------------- | ---------- | ------------------------------------------------------- |
| Task: feature implementation | `feat`     | `#86 feat(86-black-jack-page): add SSE endpoint`        |
| Task: tests                  | `test`     | `R2-50 test(R2-50-user-id-db): add unit tests`          |
| Task: validation from plan   | `chore`    | `#86 chore(86-black-jack-page): add validation`         |
| Polish                       | `refactor` | `#86 refactor(86-black-jack-page): simplify components` |
| Validate fix                 | `fix`      | `#86 fix(86-black-jack-page): fix lint errors`          |
| Documentation                | `docs`     | `#86 docs(86-black-jack-page): update docs`             |
| Format                       | `chore`    | `#86 chore(86-black-jack-page): format code`            |

---

## Rules

- One commit — one logical change.
- Ticket ID first in the message (if present).
- Avoid `wip`, `temp`, `misc`.
- Exclude secrets and credentials.
- Exclude `Co-Authored-By`, `Signed-off-by` and any trailer lines.
- Commit message: concise, specific, imperative mood, in English.
- Task with implementation and tests — type `feat` (tests ship together with the feature).
- Task with tests only — type `test`.
