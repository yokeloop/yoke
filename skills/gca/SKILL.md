---
name: gca
description: Git staging and commit with smart file grouping. Activated when the user writes "commit", "gca", "make a commit", "commit changes", or after /task, /plan, /do, /review.
---

# Git Commit with smart grouping

Commit orchestrator: determines context, classifies files, groups them into atomic commits, forms messages. Standalone mode runs autonomously — no confirmation prompts.

---

## Step 1 — Context

One call:

```bash
git branch --show-current; echo "==="; git status --porcelain; echo "==="; git diff HEAD --stat
```

`git status --porcelain` already lists untracked files (`??`). No changes — tell the user and stop.

---

## Step 2 — Mode

- **yoke-flow** — `$ARGUMENTS` is a path under `docs/ai/` (or a slug), or recent artifacts exist in `docs/ai/*/`. `SLUG` = path or directory name.
- **standalone** — otherwise. `SLUG` = current branch without prefix (`feature/`, `fix/`, `hotfix/`, `bugfix/`, `release/`). On `main`/`master`/`develop` — no slug.

---

## Step 3 — Ticket ID (no questions)

Cascade, first match wins. If none matches — commit without a ticket; never ask.

1. **`$ARGUMENTS`** — `86`/`#86` → `#86`; `R2-50` → `R2-50`; issue URL → `#86`; YouTrack `/issue/PROJ-123` → `PROJ-123`.
2. **slug** (yoke-flow) — leading `\d+` → `#NN`; leading `R\d+-\d+` → as-is.
3. **branch** (standalone) — `^(\d+)-` or `\/(\d+)-` → `#NN`; `(R\d+-\d+)` → as-is; `([A-Z]+-\d+)` → as-is.

Edge cases (anti-patterns, URL forms): `reference/commit-convention.md`.

---

## Step 4 — Staging

### yoke-flow

Stage only the artifact of the just-completed stage under `docs/ai/<SLUG>/`, matched by filename suffix. Leave non-artifact changes (code, configs) uncommitted — they are out of scope here. If no matching artifact changed, say so and stop.

| Stage   | Artifact suffix | Message                                                 |
| ------- | --------------- | ------------------------------------------------------- |
| /task   | `*-task.md`     | `#86 docs(86-black-jack-page): add task definition`     |
| /plan   | `*-plan.md`     | `#86 docs(86-black-jack-page): add implementation plan` |
| /do     | `*-report.md`   | `#86 docs(86-black-jack-page): add execution report`    |
| /review | `*-review.md`   | `#86 docs(86-black-jack-page): add review report`       |

### standalone (autonomous)

gca commits the **entire working tree** — every modified and untracked entry from `git status --porcelain`, no matter who produced the change (this session, another session, or the user editing by hand). Git tracks working-tree state, not per-session authorship; never exclude a file because "it wasn't my edit" or "I don't know the context." Filtering by provenance forces the user to re-run gca.

Classify each file by path, then group into atomic commits — no confirmation:

| Group          | Path pattern                                    | Type                    |
| -------------- | ----------------------------------------------- | ----------------------- |
| feature        | `src/`, `app/`, `lib/`, `pages/`, `components/` | `feat`/`fix`/`refactor` |
| test           | `*.test.*`, `*.spec.*`, `__tests__/`, `*.cy.*`  | `test`                  |
| docs           | `*.md`, `docs/`, README, CHANGELOG              | `docs`                  |
| style          | formatter-only output, no logic change          | `style`                 |
| chore          | `package.json`, `*.config.*`, `.eslintrc`, CI   | `chore`                 |
| yoke-artifacts | `docs/ai/**`                                    | `docs`                  |

Precedence when a file matches several rows: yoke-artifacts > test > style > chore > docs > feature. `perf` and `style` are content-judgement types, not path-derivable — apply them only when the diff clearly warrants it.

Grouping: feature + test of one feature → one commit; chore, style, yoke-artifacts → separate. Order: chore → feature → style → docs → yoke-artifacts. Full algorithm: `reference/staging-strategy.md`.

Exclusions are narrow and apply only to **untracked** (`??`) files: a new `.env`/`.env.*`, a raw key or credential file (`*.pem`, `*.key`, `*.p12`, `id_rsa`, files plainly named as credentials), or a binary over 1MB. Tracked files are always committed — git-crypt-managed files included, since the clean filter encrypts them on commit. Don't ask; commit everything else and list any excluded file in the final report.

---

## Step 5 — Messages

Format `TICKET type(SLUG): description` — NO colon after the ticket; omit the ticket or slug when absent. English, imperative mood, one sentence: what, not how. Types: feat, fix, refactor, docs, test, chore, style, perf.

---

## Step 6 — Commit

For each planned commit, batched in one turn:

1. `git add <files by name>` — never `git add -A` or `git add .`
2. `git commit -m "<message>"` — no trailers, no Co-Authored-By
3. Report: hash, message, files. Note any excluded files.

---

## Rules

- English commits, no exceptions.
- One commit — one logical change.
- Ticket first when present; never a colon after it.
- Stage files by name.
- Standalone commits the whole working tree; never skip a file because another session or the user changed it.
- Exclude only untracked secrets, credentials, and >1MB binaries; always commit tracked files, git-crypt included.
- Avoid `wip`, `temp`, `misc`.
- No `Co-Authored-By`, `Signed-off-by`, or trailer lines.
- Standalone commits run without confirmation.

## Reference

- `reference/commit-convention.md` — format edge cases, ticket forms, type table, yoke-artifact messages.
- `reference/staging-strategy.md` — full classification and grouping algorithm, order, safeguards (standalone).
