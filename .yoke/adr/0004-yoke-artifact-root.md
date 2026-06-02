# 4. Unified `.yoke/` root for all yoke artifacts

Date: 2026-05-30

## Status

Accepted

## Context

yoke artifacts are scattered. PRDs, tasks, plans, reports, explorations and the
issues index live under `docs/ai/<slug>/`; the domain glossary lives at the repo
root as `CONTEXT.md`; ADRs live in `docs/adr/`. Each skill hard-codes its own
location, and `do` even probes `.gitignore` for `docs/ai/` to decide whether to
commit. There is no single place a human or an agent can look to find "what yoke
knows about this project", and no single convention a new skill can rely on.

The user wants one root — `.yoke/` — that holds everything yoke produces, so
every skill reads and writes the same predictable layout.

Alternatives considered:

- **Keep `docs/ai/` + root `CONTEXT.md` + `docs/adr/`** — rejected: the spread is
  exactly the problem; "where does this go?" has three different answers.
- **Move only the AI pipeline to `.yoke/`, keep `CONTEXT.md` and ADRs in `docs/`**
  — considered: keeps domain docs human-prominent. Rejected by the user in favour
  of a single root, so there is one answer to "where is yoke state".
- **A `.yoke/config.json` manifest that records paths** — rejected: a fixed path
  convention needs no parsing and no contract to keep in sync.

## Decision

All yoke artifacts live under a single `.yoke/` root in the target project, with
a fixed path convention (no manifest):

- `.yoke/context.md` — the domain glossary (was root `CONTEXT.md`).
- `.yoke/adr/` — architecture decision records (was `docs/adr/`).
- `.yoke/ai/<slug>/` — per-task pipeline artifacts: PRD, plan, report,
  exploration, issues index (was `docs/ai/<slug>/`).
- `.yoke/journal.md` — the session journal.

`.yoke/` is **committed to git by default**; the user may add it to `.gitignore`
if they want artifacts kept local. Skills no longer probe `.gitignore` to decide
the location — they always write to `.yoke/` and commit unless it is ignored.

Every skill that reads or writes an artifact is updated to this convention:
`grill-docs`, `prd`, `issues`, `review`, `do`, `gca`, `bootstrap`, and the
agents under them. `bootstrap` scaffolds the `.yoke/` layout for a new project.

The ADRs themselves migrate from `docs/adr/` into `.yoke/adr/` as part of the
epic that implements this decision; this record is authored in `docs/adr/` for
continuity with 0001–0003 and moves with the rest.

## Consequences

Positive:

- One answer to "where does yoke state live" — for humans and agents.
- New skills inherit the layout for free; no per-skill path decisions.
- Memory (journal + artifacts) has a stable home that the future git-layer
  (issue #2) and `/yoke:journal` can index.

Negative / costs:

- Breaking change: existing repos using `docs/ai/` and root `CONTEXT.md` must
  migrate. This is a 2.0.0 change; no automatic migration of pre-existing repos
  is provided (out of scope for the epic).
- Domain docs (glossary, ADRs) are no longer in the conventional `docs/`
  location, so a reader must know the `.yoke/` convention.
- Touches nearly every skill at once; the path migration is the spine the rest
  of the 2.0 epic depends on.
