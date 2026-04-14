# Skill /gca

Creates atomic commits with automatic ticket binding. Resolves the ticket ID from arguments, the branch,
or SP flow; classifies files into groups; and formats messages per Conventional Commits.
Works in two modes: SP flow (commit an artifact) and standalone (group files).

## Input

`$ARGUMENTS` (optional) — ticket ID, ticket URL, or slug.

```
/sp:gca
/sp:gca #86
/sp:gca https://github.com/owner/repo/issues/86
```

## Phases

| Phase | Name                | What happens                                                                                 |
| ----- | ------------------- | -------------------------------------------------------------------------------------------- |
| 1     | **Collect context** | Parallel queries: git status, diff, branch, ls-files                                         |
| 2     | **Mode**            | Detect SP flow (task/plan/do/review artifact) or standalone                                  |
| 3     | **Ticket ID**       | Cascade: arguments → slug (SP) → branch (standalone) → ask the user                          |
| 4     | **Staging**         | SP flow: artifact only. Standalone: classify into 6 groups, plan atomic commits              |
| 5     | **Commit message**  | Format: `TICKET type(SCOPE): description` — English, imperative mood                         |
| 6     | **Commit**          | Stage specific files, commit, display the result                                             |

## Commit format

```
TICKET type(SCOPE): description
```

- **TICKET** — first: `#86` for GitHub, `R2-50` for YouTrack. Omitted when no ticket
- **type** — feat, fix, refactor, docs, test, chore, style, perf
- **SCOPE** — area of changes (optional)
- **description** — English, imperative mood

Examples: `#86 feat(pages): add blackjack page`, `R2-50 fix: save user ID to database`

## Modes

| Mode           | When                             | Behavior                                                           |
| -------------- | -------------------------------- | ------------------------------------------------------------------ |
| **SP flow**    | Invoked from `/task`, `/plan`, `/do` | Commit only the current stage artifact, no classification         |
| **Standalone** | Direct user invocation           | Classify files into 6 groups, determine atomic commits             |

## File groups (standalone)

| Group        | Files                                          |
| ------------ | ---------------------------------------------- |
| feature      | Main code (src/, lib/, app/)                   |
| test         | Tests (\*.test.\*, \*.spec.\*, \_\_tests\_\_/) |
| docs         | Documentation (README, CHANGELOG, \*.md, JSDoc) |
| style        | Formatting without logical changes             |
| chore        | Configs, CI, dependencies                      |
| sp-artifacts | Files under docs/ai/                           |

## Example

```
/sp:gca #86
```

Result: one or more atomic commits bound to ticket #86.

## Connections

Used at the end of each skill: `/task` → `/gca`, `/plan` → `/gca`, `/do` → `/gca`, `/review` → `/gca`.
Standalone — for regular commits outside SP flow.
