# 5. `do` as the universal execution tool; remove `task` and `plan`

Date: 2026-05-30

## Status

Accepted

## Context

`task` and `plan` predate `grill`, `grill-docs`, `prd` and `issues`. Their job
was to formalise *what* to do (`task`) and *how* to do it (`plan`) before `do`
executed. Today `grill`/`grill-docs`/`prd`/`issues` already formalise the *what*
and persist it as artifacts, so `task` and `plan` largely duplicate that step.
The one piece still worth keeping is `plan`'s "how and where we change the code"
working-out.

Separately, `do` today is single-mode: it expects a plan-file path and runs a
fixed sub-agent pipeline. The user wants `do` to be usable at any depth of the
flow — `grill`→`do`, `grill-docs`→`prd`→`do`, or `grill-docs`→`prd`→`issues`→`do`
— accepting any of those as its task.

Alternatives considered:

- **Keep `task`/`plan` as-is** — rejected: duplicates `grill`/`prd`, and the
  user explicitly wants them gone.
- **Fold the "how/where" step into a new dedicated skill** — rejected: it belongs
  with execution; splitting it just recreates the `plan`→`do` handoff.
- **Make the caller pick the `do` mode via a flag** — rejected in favour of
  auto-detection; the user wants a single `/do` that figures out the shape.

## Decision

`do` becomes the universal execution tool and absorbs the surviving part of
`task`/`plan` (the "how and where we change the code" working-out, recorded as a
plan artifact under `.yoke/ai/<slug>/`).

`do` **auto-detects its mode** from the input:

- **Inline** — a small task described in chat (e.g. after `grill`). Plans
  briefly in chat, executes in the current session, no pause.
- **Sub-agents** — a single issue. Writes a full plan artifact, pauses for
  confirmation, then executes via sub-agents.
- **Team** — a PRD ticket with many sub-issues. Writes a full plan artifact,
  pauses for confirmation, then dispatches a team of agents.

The pre-execution plan artifact is **mode-dependent**: inline writes a short plan
and proceeds; sub-agents/team write the full `<slug>-plan.md` and pause for
review before the heavy run.

`task` and `plan` are moved to the top-level `deprecated/` directory (out of
auto-discovery), together with the other unused skills (`fix`, `gst`,
`explore`). `sync-docs` is not deprecated but relocated to `.claude/skills/` as
a repo-internal skill, since it only maintains this repo's docs site.

## Consequences

Positive:

- One execution entry point that scales from a one-off chat task to a multi-issue
  PRD, instead of a fixed `task`→`plan`→`do` chain.
- The "how/where" reasoning is preserved and persisted as a plan artifact, now
  under `.yoke/ai/`.
- Fewer shipped skills to learn and maintain.

Negative / costs:

- Auto-detection is a heuristic; a misread input picks the wrong mode. The
  sub-agents/team pause for confirmation is the guard against an expensive
  wrong run.
- `do` grows in surface area — it now owns planning plus three execution modes;
  the SKILL.md must keep the modes clearly separated.
- Removing `task`/`plan` is a breaking change for anyone invoking them directly
  (2.0.0).
