# Commit Convention

Commit format for yoke skills and standalone invocations. This is the write
side of the **git memory** (ADR-0012): commit messages carry the project's
decision history, written for coding agents as the primary readers. The read
side — how to recover that history — lives in `history-reading.md`.

---

## Git initiative and defaults

Plugin-wide contract for when the agent may run git and how commits are shaped.

- **Authorization.** A skill invocation (`/do`, `/merge`, `/gca`, `/gp`, `/pr`) authorizes the git operations that skill performs — commit, push, PR — with no mid-run "commit?" questions.
- **Initiative.** Outside skill runs the agent never commits or pushes on its own initiative — only on an explicit user command.
- **Language.** Commit messages default to English; a project may override via `.yoke/flow.md` or its `CLAUDE.md`.
- **Trailers.** Never add identity trailers (`Co-Authored-By`, `Signed-off-by`, and the like). Decision trailers from the Body section are different — they carry memory, use them.
- **Identity.** Never fabricate committer identity (no `git -c user.email=...`); when identity is missing, ask the user.

---

## Format

```
TICKET type(SLUG): description
```

Example: `#86 feat(86-black-jack-page): add game page`

- **Language**: English by default (see "Git initiative and defaults").
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

## Body — the git memory

The subject says what; the body says **why**. The body is the Decision
Shadow — the context that lived in the author's head when the code was
written and dies with the session unless it lands here. A future agent
recovers it with `git log -- <path>` (see `history-reading.md`).

### When a body is required

By content, not by type. Write a body when the commit carries a decision — a
chosen approach, a rejected alternative, a non-obvious constraint. The test:
**will a reader six months out wonder "why"?** Mechanical commits (dependency
bumps, formatting, generated files) stay one-liners.

### Shape

1. **Prose** — one or two short paragraphs of reasoning: why this approach,
   what constraint drove it, what almost worked. Plain sentences, no headings,
   no diff narration.
2. **Decision trailers** — after the prose, from the fixed vocabulary:

| Trailer       | Carries                                                         |
| ------------- | --------------------------------------------------------------- |
| `Constraint:` | An active rule the code must keep respecting                    |
| `Rejected:`   | An approach considered or tried and dismissed — with the reason |
| `Directive:`  | A warning to whoever touches this code next                     |
| `Related:`    | A pointer: ticket, commit hash, or `.yoke/` artifact path       |

Every trailer is optional — write one only when there is real content; repeat
a key for multiple entries. Only these four keys: a fixed vocabulary is what
keeps the history greppable (`git log --grep="^Rejected:"`).

### Example

```
#86 feat(86-black-jack-page): add SSE endpoint

Polling was dropped: the kiosk network kills idle HTTP/1.1
connections after 30s, SSE with retry survives it. Score state
lives server-side because the client is untrusted.

Rejected: WebSocket — no proxy support on kiosks
Constraint: client is untrusted, never move score calc there
Related: #84
```

### Body anti-patterns

```
# WRONG — diff narration, not a decision:
Added handleRetry() that retries the request and updated the tests.

# WRONG — ritual trailers with no content:
Constraint: none
Confidence: high          # not in the vocabulary; self-assessment is noise

# RIGHT — the decision and its reason:
Retry lives in the client because the gateway strips Retry-After;
see the rejected server-side attempt in a1b2c3d.
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

Within yoke flow (`/do` → PR, `/merge`) the ticket ID is extracted from the slug:

| Slug pattern                               | Ticket ID | Example |
| ------------------------------------------ | --------- | ------- |
| Starts with a number: `86-black-jack-page` | `#86`     | `#86`   |
| Starts with `R\d+-\d+`: `R2-50-user-id-db` | `R2-50`   | `R2-50` |
| Without ID: `fix-navbar-overflow`          | none      | omit    |

### No ticket found

If the cascade yields nothing, commit without a ticket — omit the ticket and its trailing space. Do not ask.

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

Slug = task directory name (e.g. `86-black-jack-page` from `.yoke/ai/86-black-jack-page/`). Source: active task/plan file in `.yoke/ai/` or the passed path.

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
- A commit that carries a decision gets a prose body and, when there is
  content, decision trailers — see "Body — the git memory".
- Avoid `wip`, `temp`, `misc`.
- Staging/exclusion policy lives in `staging-strategy.md`: gca excludes only untracked secrets, keys, and >1MB binaries, and always commits tracked files, git-crypt included. Never exclude a file by authorship.
- Git initiative, message language, trailers, and committer identity follow "Git initiative and defaults".
- Commit message: concise, specific, imperative mood.
- Task with implementation and tests — type `feat` (tests ship together with the feature).
- Task with tests only — type `test`.
