# CONTEXT — yoke glossary

Canonical vocabulary for the yoke plugin and its flow. Glossary only — no
implementation details (those live in `.yoke/adr/` and the PRDs under
`.yoke/ai/`).

## Components

- **Skill** — a model-invoked capability auto-discovered by `skills/<name>/SKILL.md`,
  activated by its `description`. Shipped to users via the marketplace.
- **Command** — a user-invoked entry point (`/yoke:<name>`).
- **Agent** — a sub-agent dispatched by a skill orchestrator via the Agent tool
  (`skills/<name>/agents/<agent>.md`).
- **Internal skill** — a skill that is NOT shipped to users; it lives in
  `.claude/skills/` because it only makes sense for this repository (e.g.
  `yoke-create`, `yoke-release`, `sync-docs`). Distinct from a deprecated skill.
- **Deprecated skill** — a skill removed from auto-discovery by moving it to the
  top-level `deprecated/` directory. Kept for reference, not loaded, not shipped.

## Artifacts and storage

- **Artifact** — any file yoke produces about the work (PRD, plan, report,
  exploration, issues index, execution report).
- **`.yoke/`** — the single root for everything yoke produces in a target
  project. Committed to git by default (the user may gitignore it). Fixed path
  convention, no manifest:
  - `.yoke/context.md` — this glossary.
  - `.yoke/adr/` — architecture decision records.
  - `.yoke/ai/<slug>/` — per-task pipeline artifacts (PRD, plan, report, …).
  - `.yoke/journal.md` — session journal.
- **Slug** — kebab-case task identifier, optionally prefixed with a ticket id
  (e.g. `16-direct-telegram-notifications`). Names the `.yoke/ai/<slug>/` folder.

## Memory

- **Memory** — the project's accumulated decision history, in connected layers:
  - **Journal** (`.yoke/journal.md`) — short, chronological index of sessions;
    the entry point for "what was done and where to look".
  - **Artifacts** (`.yoke/ai/`) — the full detail behind each journal entry.
  - **Git layer** (future, issue #2) — commit trailers / GitHub comments that
    tie commits and issues back to the artifacts. Deferred to a later release.

## do modes

`do` is the universal execution tool; it auto-detects its mode from the input:

- **Inline mode** — input is a small task described in chat (e.g. `grill` → `do`).
  Plans briefly in chat, executes in the current session, no pause.
- **Sub-agents mode** — input is a single issue. Writes a full plan artifact,
  pauses for confirmation, then executes via sub-agents.
- **Team mode** — input is a PRD ticket with many sub-issues. Writes a full plan
  artifact, pauses for confirmation, then dispatches a team of agents.

## Flow

- **grill / grill-docs** — interrogate the plan; formalise _what_ to do; maintain
  `.yoke/context.md` and `.yoke/adr/`.
- **prd** — synthesise a PRD artifact and publish it as a GitHub issue.
- **issues** — break a PRD into independently-grabbable sub-issues.
- **do** — work out _how/where_ to change the code (recorded as a plan artifact),
  then execute. Absorbs the former `task` and `plan` skills.
- **journal** — append a session summary to `.yoke/journal.md` (manual `/yoke:journal`).
