# Skill /pr

Creates or updates a GitHub Pull Request. Builds the description from yoke flow artifacts
(review + report), with a focus on "what to check during review". Without artifacts, falls back
to commits and diff. Supports PR templates, auto-labels, and update markers.

## Input

`$ARGUMENTS` (optional) — flags: `--draft`, `--base <branch>`.

```
/yoke:pr
/yoke:pr --draft
/yoke:pr --base develop
```

## Phases

| Phase | Name         | What happens                                                                         |
| ----- | ------------ | ------------------------------------------------------------------------------------ |
| 1     | **Collect**  | Sub-agent collects: branch, slug, PR, review/report files, template, commits, labels |
| 2     | **Decide**   | Orchestrator: blocking errors, create vs update, draft, DATA_SOURCE                  |
| 3     | **Generate** | Sub-agent synthesizes the PR body from review/report or fallback                     |
| 4     | **Execute**  | Orchestrator: `gh pr create` or `gh pr edit`, labels                                 |
| 5     | **Next**     | Orchestrator: completion                                                             |

## Data sources (DATA_SOURCE)

| Source       | Condition             | PR body contents                                                  |
| ------------ | --------------------- | ----------------------------------------------------------------- |
| `sp_full`    | review + report found | Summary, Attention, Design decisions, Questions, Risks, Test plan |
| `sp_partial` | report only           | Summary, Test plan, Changes, Commits                              |
| `fallback`   | no yoke artifacts     | Summary from commits, Changes, Commits, generic Test plan         |

## PR body

Generated content is wrapped in `<!-- yoke:start -->` / `<!-- yoke:end -->` markers.
On update, only the content between the markers is replaced — the user's text is preserved.

Principle: the description answers "what to check during review".

## Auto-link and auto-labels

Ticket ID from slug: `86-feature` → `Closes #86`, `R2-208-feature` → `Ticket: R2-208`.

Labels from commit types: `feat` → `enhancement`, `fix` → `bug`, `refactor` → `maintenance`.
Only labels that exist in the repository are applied.

## Sub-agents

| Agent               | Model  | Role                                                        |
| ------------------- | ------ | ----------------------------------------------------------- |
| `pr-data-collector` | haiku  | Collects data: PR, review/report, template, commits, labels |
| `pr-body-generator` | sonnet | Synthesizes the PR body from artifacts (reasoning task)     |

## Example

```
/yoke:pr
```

Result: a PR on GitHub with a structured description from review and report.

## Connections

Typical flow: `/task` → `/plan` → `/do` → `/review` → `/gca` → `/gp` → `/pr`.
Works standalone — creates a PR from commits without yoke artifacts.
Uses `reference/pr-body-format.md` for body format and section mapping.
