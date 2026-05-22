# Skill /pr

Creates or updates a GitHub Pull Request. Builds the description from yoke flow artifacts
(review + report), focusing on "what to check during review". Falls back to commits and diff when
artifacts are absent. Supports PR templates, auto-labels, and update markers. Runs autonomously —
no confirmation prompts.

## Input

`$ARGUMENTS` (optional) — flags: `--draft`, `--base <branch>`.

```
/yoke:pr
/yoke:pr --draft
/yoke:pr --base develop
```

## Steps

| Step | Name         | What happens                                                                      |
| ---- | ------------ | --------------------------------------------------------------------------------- |
| 1    | **Collect**  | `lib/pr-collect.sh` collects fields and file paths: branch, PR, artifacts, labels |
| 2    | **Decide**   | Orchestrator: blocking errors, create vs update, DATA_SOURCE, draft, base         |
| 3    | **Generate** | `pr-body-generator` (Sonnet) reads artifacts and synthesizes the PR body          |
| 4    | **Execute**  | Orchestrator: `gh pr create` / `gh pr edit` via `--body-file`, labels, notify     |

## Data sources (DATA_SOURCE)

| Source         | Condition             | PR body contents                                                  |
| -------------- | --------------------- | ----------------------------------------------------------------- |
| `yoke_full`    | review + report found | Summary, Attention, Design decisions, Questions, Risks, Test plan |
| `yoke_partial` | report only           | Summary, Test plan, Changes, Commits                              |
| `fallback`     | no yoke artifacts     | Summary from commits, Changes, Commits, generic Test plan         |

## PR body

Generated content is wrapped in `<!-- yoke:start -->` / `<!-- yoke:end -->` markers.
On update, only the content between the markers is replaced — the user's text is preserved.
The generator reads artifact files itself (by path), so their content never enters the orchestrator.

Principle: the description answers "what to check during review".

## Auto-link and auto-labels

Ticket ID from slug: `86-feature` → `Closes #86`, `R2-208-feature` → `Ticket: R2-208`.

Labels from commit types: `feat` → `enhancement`, `fix` → `bug`, `refactor` → `maintenance`.
Only labels that exist in the repository are applied.

## Components

| Component           | Kind          | Role                                                    |
| ------------------- | ------------- | ------------------------------------------------------- |
| `lib/pr-collect.sh` | script        | Collects fields and artifact paths (read-only)          |
| `pr-body-generator` | agent, sonnet | Synthesizes the PR body from artifacts (reasoning task) |

## Example

```
/yoke:pr
```

Result: a PR on GitHub with a structured description from review and report.

## Connections

Typical flow: `/task` → `/plan` → `/do` → `/review` → `/gca` → `/gp` → `/pr`.
Works standalone: creates a PR from commits without yoke artifacts.
Uses `reference/pr-body-format.md` for body format and section mapping.
