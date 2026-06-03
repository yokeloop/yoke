# yoke 2.0 — Global Refactor

**Tracking:** https://github.com/yokeloop/yoke/issues/17

> **Epic.** This PRD is a parent for a set of sub-issues. Break it down with
> `/yoke:issues`. Sequencing and dependencies are in
> [Implementation Decisions](#implementation-decisions).

## Problem Statement

yoke grew organically and now carries the seams of that growth:

- **Artifacts are scattered.** PRDs, tasks, plans, reports, explorations and the
  issues index live under `docs/ai/<slug>/`; the glossary lives at the repo root
  as `CONTEXT.md`; ADRs live in `docs/adr/`. Each skill hard-codes its own
  location and `do` even probes `.gitignore` to decide where to write. There is
  no single place to look for "what yoke knows about this project".
- **`task` and `plan` are legacy.** They were built before `grill`,
  `grill-docs`, `prd` and `issues`. Those newer skills already formalise _what_
  to do and persist it; `task`/`plan` now duplicate that. The only part still
  worth keeping is `plan`'s "how and where we change the code" working-out.
- **`do` is single-mode.** It expects a plan-file path and runs one fixed
  sub-agent pipeline. It cannot be used at an arbitrary depth of the flow
  (straight after `grill`, after a single issue, or over a whole PRD).
- **Dead weight.** `fix`, `gst`, `explore` are effectively unused but still
  shipped and discoverable. `sync-docs` is shipped to users even though it only
  maintains _this_ repo's docs site — it was miscategorised as a public skill.
- **No project memory.** Every session starts cold. There is no running record
  of what was done and where to look for the detail behind it.
- **Notifications are unreliable** (see issue #16 and ADR 0003).

The user wants a clean 2.0: one artifact root, a universal `do`, fewer skills, a
session journal as the first layer of memory, a reworked `bootstrap`, and the
notification simplification folded in.

## Solution

A single breaking 2.0 release that:

- Moves **everything yoke produces** into one committed root, `.yoke/`, with a
  fixed path convention (`.yoke/context.md`, `.yoke/adr/`, `.yoke/ai/<slug>/`,
  `.yoke/journal.md`) — recorded in **ADR 0004**.
- Collapses `task` + `plan` into a **universal `do`** that auto-detects its
  execution shape (inline / sub-agents / team) and records its own "how/where"
  plan artifact — recorded in **ADR 0005**.
- Retires unused skills to a `deprecated/` directory and relocates `sync-docs`
  to `.claude/skills/` as a repo-internal skill.
- Adds a **`/yoke:journal`** skill — the first memory layer (a short,
  chronological index under `.yoke/journal.md` that points at the artifacts).
- Reworks **`bootstrap`** to scaffold the `.yoke/` layout and prepare a repo for
  the new flow.
- Folds in the **direct Telegram notifications** change (issue #16, ADR 0003),
  with an escape hatch: if direct send proves unreliable in practice, remove
  notifications entirely.

From the user's perspective: one predictable place for everything yoke writes,
one execution command that scales from a one-off chat task to a multi-issue PRD,
a smaller and clearer skill set, and a memory trail to refer back to.

The deeper git-backed memory (Lore Protocol / GitHub comments, issue #2) is
explicitly **deferred to 2.1** — this epic lays the foundation (journal +
artifacts) it will build on.

## User Stories

### Unified artifact root (`.yoke/`)

1. As a yoke user, I want every artifact yoke produces to live under one `.yoke/`
   root, so that I always know where to look for project state.
2. As a yoke user, I want `.yoke/` committed to git by default, so that artifacts
   are part of the project history and visible in PRs and reviews.
3. As a yoke user, I want to be able to `.gitignore` `.yoke/` if I prefer, so
   that I can keep artifacts local without changing any skill.
4. As a yoke user, I want the glossary at `.yoke/context.md`, ADRs in
   `.yoke/adr/`, pipeline artifacts in `.yoke/ai/<slug>/`, and the journal at
   `.yoke/journal.md`, so that the layout is predictable without a config file.
5. As a skill author, I want a fixed path convention rather than a manifest, so
   that a new skill inherits the layout with no parsing and no contract to sync.
6. As a maintainer, I want every skill that reads or writes an artifact updated
   to `.yoke/` in one pass, so that no skill is left writing to the old
   `docs/ai/` or root `CONTEXT.md`.
7. As a yoke user, I want skills to stop probing `.gitignore` to decide where to
   write, so that behaviour is consistent regardless of ignore rules.

### Universal `do`

8. As a yoke user, I want `do` to absorb the "how and where we change the code"
   step, so that I no longer need separate `task` and `plan` runs.
9. As a yoke user, I want a single `/do` that auto-detects its mode from the
   input, so that I don't have to tell it how to run.
10. As a yoke user finishing a quick `grill`, I want `do` to run **inline** in
    the current chat for a small task, so that trivial work isn't wrapped in
    heavy orchestration.
11. As a yoke user pointing `do` at a single issue, I want it to run in
    **sub-agents** mode, so that a self-contained ticket is executed by focused
    agents.
12. As a yoke user pointing `do` at a PRD ticket with many sub-issues, I want it
    to run in **team** mode, so that a large body of work is dispatched across a
    team of agents.
13. As a yoke user, I want `do` to write a **mode-dependent** plan artifact —
    short and inline for small tasks, a full `<slug>-plan.md` for
    sub-agents/team — so that the depth of planning matches the size of the work.
14. As a yoke user, I want `do` to **pause for my confirmation** after writing
    the full plan in sub-agents/team mode, so that I can approve an expensive run
    before it starts.
15. As a yoke user, I want the inline mode to plan briefly and proceed without a
    pause, so that small tasks stay fast.
16. As a yoke user, I want a wrong mode guess to be caught at the confirmation
    pause, so that an auto-detection mistake never triggers a costly wrong run
    unreviewed.

### Skill cleanup

17. As a maintainer, I want `fix`, `gst`, `explore`, `task` and `plan` moved to a
    `deprecated/` directory out of auto-discovery, so that they stop loading and
    stop shipping while remaining recoverable from git.
18. As a yoke user, I want a smaller, clearer set of shipped skills, so that the
    marketplace surface is easier to learn.
19. As a maintainer, I want `sync-docs` relocated to `.claude/skills/` as a
    repo-internal skill, so that the docs site keeps regenerating without
    shipping a repo-specific skill to every user.
20. As a maintainer, I want the deprecation/relocation reflected in `README.md`,
    `CLAUDE.md` and the public catalog, so that the documentation matches the
    shipped set.

### Journal & memory foundation

21. As a yoke user, I want a `/yoke:journal` skill that appends a short summary of
    the session's work to `.yoke/journal.md`, so that there is a running record
    of what was done.
22. As a yoke user, I want the journal triggered manually (not by a hook), so
    that I control when an entry is written and the plugin stays hook-free.
23. As a yoke user, I want each journal entry to point at the relevant
    `.yoke/ai/<slug>/` artifacts, so that the journal is an index into the detail.
24. As a yoke user, I want to refer back to the journal to find past decisions and
    history, so that later sessions are not cold starts.
25. As a maintainer, I want the journal to be the first layer of a future
    connected memory system (journal → artifacts → git layer), so that issue #2
    can build on it without rework.

### Bootstrap

26. As a new yoke user, I want `bootstrap` to scaffold the `.yoke/` layout, so
    that my repo is ready for the new flow in one command.
27. As a new yoke user, I want `bootstrap` to detect my stack and seed
    `.yoke/context.md` and the project context, so that downstream skills have
    grounding from the start.
28. As a new yoke user, I want `bootstrap` to wire `CLAUDE.md` to point at
    `.yoke/`, so that the agent and other skills know the conventions.
29. As a maintainer, I want `bootstrap` aligned with every other 2.0 convention,
    so that a freshly bootstrapped repo and a hand-set-up repo are identical.

### Notifications (folds in issue #16)

30. As a yoke user, I want notifications sent by a single direct inline call per
    ADR 0003, so that pings arrive when the event happens and nothing is lost.
31. As a maintainer, I want the Stop hook, `hooks.json`, the `hooks/` directory
    and the `.yoke/notify-pending.json` queue removed, so that no dead machinery
    remains.
32. As a maintainer, I want an escape hatch: if direct send proves unreliable in
    practice, remove the notification story entirely, so that we don't keep a
    flaky feature alive.

### Versioning

33. As a maintainer, I want this released as **2.0.0**, so that the breaking
    changes (removed skills, new artifact paths) are honestly signalled.

## Implementation Decisions

This epic is a set of sub-issues. Implement the **foundation first** — the
`.yoke/` path convention is the spine everything else depends on.

### Sub-issue 1 — `.yoke/` artifact convention (foundation)

- Establish the fixed layout: `.yoke/context.md`, `.yoke/adr/`,
  `.yoke/ai/<slug>/`, `.yoke/journal.md` (ADR 0004).
- Migrate every read/write path across the skills and their agents:
  `grill-docs`, `grill`, `prd`, `issues`, `review`, `do`, `gca`, `bootstrap`,
  `handoff`. Move the glossary from root `CONTEXT.md` to `.yoke/context.md` and
  the ADR directory from `docs/adr/` to `.yoke/adr/`.
- Remove the `.gitignore`-probing logic in `do`; always write to `.yoke/` and
  commit unless the root is ignored.
- This sub-issue blocks 2–6.

### Sub-issue 2 — Deprecate/relocate skills

- Move `fix`, `gst`, `explore`, `task`, `plan` into a top-level `deprecated/`
  directory (out of auto-discovery) (ADR 0005).
- Relocate `sync-docs` from `skills/` to `.claude/skills/` as a repo-internal
  skill; the docs site keeps regenerating, the skill is no longer shipped.
- Update `README.md`, `CLAUDE.md` and the public catalog to the new shipped set.

### Sub-issue 3 — `do` rework into a universal orchestrator

- `do` absorbs the surviving "how/where we change the code" planning from
  `task`/`plan`, recorded as a plan artifact under `.yoke/ai/<slug>/` (ADR 0005).
- **Mode auto-detection** from the input:
  - **Inline** — a small task described in chat → plan briefly in chat, execute
    in the current session, no pause.
  - **Sub-agents** — a single issue → write full `<slug>-plan.md`, pause for
    confirmation, execute via sub-agents.
  - **Team** — a PRD ticket with many sub-issues → write full `<slug>-plan.md`,
    pause for confirmation, dispatch a team of agents.
- The plan artifact is mode-dependent (short inline vs full file).
- The existing `do` sub-agent pipeline (executor → reviewer → validator →
  formatter → report) is the basis for sub-agents/team modes.
- Supersedes/absorbs issue **#5** (`/yoke:do V3 — execution via agent-team`); relates
  to issue **#6** (`/autopilot`), which can later sit on top of the universal `do`.

### Sub-issue 4 — `/yoke:journal` skill

- New shipped skill `journal`, invoked manually as `/yoke:journal`.
- Appends a short, newest-first session summary to `.yoke/journal.md`; each entry
  links the relevant `.yoke/ai/<slug>/` artifacts.
- No hook — the plugin stays hook-free (consistent with sub-issue 6).
- Graduates the existing repo-local `/journal` command into a real, shipped
  skill writing to the `.yoke/` convention.

### Sub-issue 5 — `bootstrap` rework

- Scaffold the `.yoke/` layout (create the root, a `context.md` skeleton, an
  empty `journal.md`, the `ai/` directory).
- Detect the project stack and seed `.yoke/context.md` / project context.
- Write or update `CLAUDE.md` to point at the `.yoke/` conventions so all skills
  and the agent know where things live.
- Align with every other 2.0 convention so a bootstrapped repo matches a
  hand-set-up one.

### Sub-issue 6 — Notifications (folds issue #16)

- Implement the direct inline `lib/notify.sh` per ADR 0003 and the existing
  issue #16 PRD; remove `hooks/notify.sh`, `hooks/hooks.json`, the `hooks/`
  directory, the `jq` dependency, and the `.yoke/notify-pending.json` queue.
- Update the call sites that survive (in the non-deprecated skills) to the
  simplified flags.
- **Acceptance with escape hatch:** if the direct inline call proves unreliable
  in practice, remove the Telegram notification story entirely (script + all
  call sites) and close issue #16 as wontfix instead.

### Cross-cutting decisions

- **Single root, no manifest** — fixed path convention, not `.yoke/config.json`
  (ADR 0004).
- **`.yoke/` committed by default**, user may gitignore.
- **2.0.0 major** — breaking: removed skills and new artifact paths.
- **Deferred:** the git-backed memory layer (Lore Protocol commit trailers /
  GitHub comments, issue **#2**) is a separate sub-epic for 2.1. This epic ships
  only the journal + artifact layers it depends on.
- **No automatic migration** of pre-existing repos from `docs/ai/` + root
  `CONTEXT.md` to `.yoke/` — greenfield convention only.

## Testing Decisions

The repository has **no automated test harness** (only Prettier via
`pnpm run format` / `format:check`; no test runner). This epic adds **no
automated test framework**; verification is manual and behavior-focused, the
same approach taken for issue #16.

Good checks here exercise observable behavior, never skill internals:

- **`.yoke/` convention** — after running each migrated skill, its artifact lands
  at the documented `.yoke/` path and nowhere under `docs/ai/` or root
  `CONTEXT.md`.
- **Skill discovery** — after deprecation, `fix`/`gst`/`explore`/`task`/`plan`
  no longer appear as `/yoke:*` skills; `sync-docs` is gone from the shipped set
  but still runnable from `.claude/`; the docs site still regenerates.
- **`do` mode detection** — a chat task triggers inline (no pause); a single
  issue triggers sub-agents with a pause; a multi-sub-issue PRD triggers team
  with a pause. The confirmation pause appears before any code change in
  sub-agents/team modes.
- **Journal** — `/yoke:journal` appends a correctly formatted, newest-first entry
  to `.yoke/journal.md` linking the session's artifacts; running it twice does
  not clobber earlier entries.
- **Bootstrap** — on a fresh repo, `bootstrap` produces the full `.yoke/`
  skeleton and a `CLAUDE.md` that references it.
- **Notifications** — per the issue #16 PRD's behavioral checks (happy path,
  opt-out when credentials unset, level filter, missing `curl`, special
  characters), all exit 0 and never write to the transcript.

Prior art: the manual behavioral checks described in the issue #16 PRD and
`docs/notify.md`, and the existing validation snippets in `CLAUDE.md`
(`python3 -c "import json…"`, `head -1 skills/*/SKILL.md`).

## Out of Scope

- The git-backed memory layer — Lore Protocol commit trailers and GitHub
  comments (issue #2). Deferred to 2.1; only the journal + artifact foundation
  ships here.
- Automatic migration of existing repos from `docs/ai/` / root `CONTEXT.md` to
  `.yoke/`. New convention applies going forward; old repos migrate by hand.
- Adding an automated test framework to the repo.
- `/autopilot` (issue #6) as a feature — out of scope here, though the universal
  `do` is a prerequisite for it.
- Any non-Telegram notification channel.
- Reworking `gca`, `gp`, `pr`, `handoff`, `help`, `grill`, `issues`, `review`
  beyond the mechanical `.yoke/` path migration in sub-issue 1.
- Changing the docs-site implementation (Astro/Starlight, ADR 0001/0002) beyond
  relocating the `sync-docs` skill that feeds it.

## Further Notes

- **ADR alignment.** This PRD introduces **ADR 0004** (unified `.yoke/` root)
  and **ADR 0005** (`do` universal, remove `task`/`plan`), and folds in **ADR
  0003** (direct Telegram send). It does not contradict ADR 0001/0002 (docs site
  on Astro/Starlight); `sync-docs` is relocated, not removed, so the site keeps
  working. The ADRs are authored in `docs/adr/` for continuity with 0001–0003
  and migrate into `.yoke/adr/` as part of sub-issue 1.
- **Glossary.** Terms used here (artifact, `.yoke/` root, internal skill,
  deprecated skill, do modes, memory layers) are defined in `.yoke/context.md`.
- **Related issues.** #16 (folded into sub-issue 6), #5 (absorbed by sub-issue
  3), #6 (`/autopilot`, downstream of sub-issue 3), #2 (deferred memory layer).
- **Sequencing.** Sub-issue 1 is the spine and must land first; 2–6 can then
  proceed largely in parallel, with 4 (journal) and 6 (notifications) the most
  independent.
- To break this epic into the sub-issues above, hand off to `/yoke:issues`.
