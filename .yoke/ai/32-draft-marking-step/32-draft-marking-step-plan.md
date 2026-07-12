# Draft marking step (#32) — implementation plan

**Task:** https://github.com/yokeloop/yoke/issues/32 (PRD: `.yoke/ai/draft-marking-step/draft-marking-step-prd.md`)
**Complexity:** medium
**Mode:** sub-agents
**Parallel:** true

A pure markdown-skill task: no application code, no manifest edits, no version bump. The glossary
(`.yoke/context.md`) and `.yoke/adr/0011-draft-optional-marking-step.md` are already written — do not touch them.
Every authoring task uses the glossary vocabulary verbatim — **Draft**, **Markup**, **Marker**, **Draft PR**,
**Draft execution** — in English, prettier-formatted (printWidth 120, proseWrap preserve).

## Design decisions

### DD-1: `/draft` is a separate shipped skill, not a `/do --draft` flag

**Decision:** New `skills/draft/` skill; `/do` gains a distinct **Draft execution** mode that consumes the Draft PR.
**Rationale:** PRD Implementation Decision #1 + ADR-0011: `do`'s contract is "drive to a ready PR"
(`skills/do/SKILL.md:12-14`); a flag would invert its semantics. Draft mirrors `do`'s architecture
(router → mode references → finish) and reuses `do`'s finish the way `do` reuses gca/gp conventions.
**Alternative:** `/do --draft` mode — inverts `do`'s "ends at PR" contract, easy to forget (ADR-0011).

### DD-2: `/draft` produces Markup in-session (orchestrator), no new implementer agent

**Decision:** `/draft` runs `do`'s Plan pipeline (investigate + architect sub-agents, by citation) to write the plan,
then the orchestrator itself writes the Markup (Markers + skeleton) per the plan's tasks. No marking sub-agent.
**Rationale:** `skills/do/agents/task-executor.md:154,173` mandates deleting `TODO/FIXME` — reusing it to _write_
Markers would erase the very Markup. Marking is a lightweight mechanical projection needing no isolated sub-agent
context.
**Alternative:** a new `marker-writer` agent — adds a component whose context isolation buys nothing for
comment/stub writing, and risks "implementing" instead of "marking."

### DD-3: One PR, draft → ready, driven through the existing finish + pr mechanics

**Decision:** `/draft` finishes each touched repo through `finish.md` §3 but passes `--draft` to the pr-skill create
call. `/do` Draft execution finds the PR already open → pr mechanics UPDATE it (draft state preserved,
`skills/pr/SKILL.md:63`) → `/do` then flips it with `gh pr ready <number>`. Never a second PR.
**Rationale:** PRD Implementation Decision #6; `skills/pr/SKILL.md:43,68` already parameterizes `--draft` on create
and leaves draft state unchanged on update. Flipping an existing PR to ready still "ends at PR" (ADR-0006 compat).
**Alternative:** a fresh implementation PR — review comments would detach from the code they anchor to (ADR-0011).

### DD-4: Router ordering — draft signals match before the sub-agents rung

**Decision:** In `skills/do/SKILL.md`, the Draft execution rung(s) resolve a PR URL (contains `/pull/`) and a bare
`<slug>` whose `.yoke/ai/<slug>/` holds a draft artifact **before** the existing issue-URL/slug sub-agents rung.
**Rationale:** `skills/do/SKILL.md:44` matches "a single issue URL, a bare `<slug>`". A bare slug is ambiguous; the
draft artifact's presence is the discriminator. Wrong order sends Draft PR URLs into sub-agents mode.
**Alternative:** in-body draft detection inside the sub-agents rung — hides the decision; a dedicated first-match
rung is explicit.

### DD-5: Read draft state ad hoc, do not extend `lib/pr-collect.sh`

**Decision:** Draft execution reads `gh pr view <url> --json isDraft,number,url` directly; no `IS_DRAFT` field in
`pr-collect.sh`.
**Rationale:** The mode is selected because the input is a draft; a one-off `gh pr view` covers the idempotence
guard. `lib/pr-collect.sh:30-46` is shared by the `pr` skill — leaving it untouched avoids regression risk.
**Alternative:** extending `pr-collect.sh` with `IS_DRAFT` — unnecessary shared-lib change for a single ad-hoc read.

### DD-6: Draft artifact `<slug>-draft.md` records the Draft PR, branch, and repo set

**Decision:** `/draft` writes `.yoke/ai/<slug>/<slug>-draft.md` holding the Draft PR URL(s), branch(es),
touched-repo set, and a pointer to `<slug>-plan.md`. `do`'s router tests for this file; Draft execution reads it.
**Rationale:** PRD Implementation Decision #7 enables `/do <slug>` from a fresh session. A fixed filename keeps the
three touch points (write in mode-draft, detect in do/SKILL.md, read in mode-draft-execution) consistent.
**Alternative:** re-deriving the PR from the branch each time — fragile across sessions and multi-repo.

### DD-7: Grep gate wording excludes doc mentions of the literal Marker string

**Decision:** The final gate greps the target project's **source** for `TODO(yoke):`, scoped to exclude `.yoke/`
artifacts and skill prose.
**Rationale:** In this repo `markup-format.md`/`mode-draft*.md`/`docs/draft.md` contain the literal string as
documentation — expected, not a leftover. `grep -rn "TODO(yoke)"` over shipped `skills/`+`lib/` returns nothing
today; the gate must stay collision-free by scoping.
**Alternative:** an unscoped repo-wide grep — would flag the skill's own documentation of the Marker.

## Tasks

### Task 1: Write the shared Markup contract `markup-format.md`

- **Files:** `skills/draft/reference/markup-format.md` (create)
- **Depends on:** none
- **Scope:** M
- **What:** Author the single source of truth for what Markup is, cited by both `/draft` (writes it) and `/do`
  Draft execution (consumes/deletes it).
- **How:** Define (1) the **Marker** — one comment in the unified format `TODO(yoke): <what will be written here>`,
  optionally carrying the plan step reference; (2) the **skeleton** — real new files, signatures, and types whose
  bodies are compilable stubs, with per-language examples (`throw new Error('TODO')`, `raise NotImplementedError`,
  Go `panic("TODO")`); (3) the invariant "the skeleton must compile / type-check; red tests are acceptable, a broken
  build is not"; (4) "Draft does not implement logic — a fully typed scaffold is explicitly out"; (5) the **grep
  gate** prefix `TODO(yoke):` and its scoping rule per DD-7.
- **Context:** `.yoke/ai/draft-marking-step/draft-marking-step-prd.md` (Implementation Decisions "Markup = markers +
  compilable skeleton", User Stories 3-5, 14); `.yoke/context.md` Draft section (quote Markup/Marker definitions);
  `skills/do/agents/task-executor.md:154,173`.
- **Verify:** `grep -n "TODO(yoke):" skills/draft/reference/markup-format.md` shows the literal defined;
  `pnpm exec prettier --check skills/draft/reference/markup-format.md` clean.

### Task 2: Write the marking procedure `mode-draft.md`

- **Files:** `skills/draft/reference/mode-draft.md` (create)
- **Depends on:** Task 1, Task 6
- **Scope:** L
- **What:** The full `/draft` procedure for both fresh marking and iteration.
- **How:** Phases: **0 Resolve** — input + flow map (`finish.md` §1) + SLUG/TICKET_ID + worktree entry (`finish.md`
  §2). **1 Plan** — reuse `mode-sub-agents.md` Phase 1 by citation (task-investigator → plan-architect → write
  `.yoke/ai/<slug>/<slug>-plan.md`); do not re-derive (cf. `mode-team.md:47`). **2 Mark** — the orchestrator writes
  Markup in-session per `markup-format.md` (DD-2), walking the plan's tasks: `TODO(yoke):` Markers in existing
  files, compilable skeleton for new structure; commit per
  `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`. **3 Draft artifact** — write
  `.yoke/ai/<slug>/<slug>-draft.md` (DD-6): Draft PR URL(s), branch(es), touched-repo set, plan pointer. **4
  Finish** — `finish.md` §3 per-repo with `--draft` forced on the pr create call, §5 ticket comment, §7 notify
  `--skill draft` with the Draft PR URL; one Draft PR per repo (multi-repo per §4). State "Draft never pauses — the
  Draft PR is the pause." **Iteration** section: on re-run against an existing Draft (slug with `<slug>-draft.md`,
  or a Draft PR URL) read the PR review comments (`gh api repos/{owner}/{repo}/pulls/{pr}/comments`), redraw the
  Markup in the same branch, push, and reply in each thread
  (`gh api --method POST repos/{owner}/{repo}/pulls/{pr}/comments -f body=... -F in_reply_to=<id>`); any number of
  rounds.
- **Context:** `skills/do/reference/mode-sub-agents.md:27-104`; `skills/do/reference/finish.md`;
  `skills/do/reference/plan-format.md`; `skills/draft/reference/markup-format.md` (Task 1); PRD Solution + User
  Stories 1-9, 16-17; `deprecated/fix/SKILL.md:264-273` (thread-reply endpoint prior art).
- **Verify:** prettier clean; the file cites `mode-sub-agents.md`, `finish.md`, `markup-format.md`, and names
  `<slug>-draft.md`.

### Task 3: Write the `/draft` orchestrator `SKILL.md`

- **Files:** `skills/draft/SKILL.md` (create)
- **Depends on:** Task 1, Task 2
- **Scope:** M
- **What:** The lean model-invoked entry point that routes to `reference/mode-draft.md`.
- **How:** YAML frontmatter: `name: draft`; `description` whose first sentence is a clean one-liner (it becomes the
  README/CLAUDE catalog line), followed by quoted trigger phrases ("draft", "mark the code", "mark up the plan",
  "draft pr", "разметь код"). Body: same **Input** contract as `do` (empty / chat description / issue URL / bare
  slug / `*-task.md`); a 2-way **Router** (fresh marking vs iteration — iteration when the input is a Draft PR URL
  or a slug with `<slug>-draft.md`); **Principles** (never pauses — the Draft PR is the pause; marks, never
  implements; artifacts under `.yoke/`; commits by convention; ends at the Draft PR); pointers to
  `reference/mode-draft.md` and `reference/markup-format.md`. Keep to ~`skills/pr/SKILL.md` length.
- **Context:** `skills/do/SKILL.md`; `skills/pr/SKILL.md`; `.claude/skills/sync-docs/SKILL.md:75-112` (how the
  description first sentence is consumed); `.yoke/context.md` Draft section.
- **Verify:** `head -1 skills/draft/SKILL.md` is `---`; frontmatter parses as YAML; prettier clean.

### Task 4: Write `/do`'s Draft execution mode `mode-draft-execution.md`

- **Files:** `skills/do/reference/mode-draft-execution.md` (create)
- **Depends on:** Task 1, Task 6
- **Scope:** L
- **What:** The `/do` mode that implements a reviewed Draft PR and flips it to ready.
- **How:** **Resolve** — the Draft PR URL (or slug → `.yoke/ai/<slug>/<slug>-draft.md`); read
  `gh pr view <url> --json isDraft,number,headRefName,url` (DD-5); check out the Draft branch (worktree per
  `finish.md` §2); read the plan artifact, the Markers in code (grep the `TODO(yoke):` prefix), and the PR review
  comments. State the **priority of voices: PR comments > Markers > plan artifact**; a comment that overturns the
  architecture (not a local correction) stops the run with AskUserQuestion instead of silently rewriting the plan.
  **Implement** — each Marker is a checklist item: build a task (What/How/Files/Verify) from the Marker + plan step +
  overriding comments and dispatch `agents/task-executor.md` verbatim, deleting each Marker together with its
  implementation; statuses and review loop per `status-protocol.md`. Multi-repo: pick up every Draft PR from the
  draft artifact, finish each per `finish.md` §4. **Reply** — in every inline comment thread describe what was done
  - commit (`gh api repos/{owner}/{repo}/pulls/{pr}/comments` list, then `--method POST ... -F in_reply_to=<id>`);
    thread resolution stays the user's. **Grep gate** (per `markup-format.md`, DD-7) — `TODO(yoke):` must return
    nothing in the implemented source before finishing; a leftover Marker blocks the ready flip. **Finish** — validate
  - format per `mode-sub-agents.md` Phase 4, report per Phase 6 (`report-format.md`), then `finish.md` §3 (the pr
    mechanics UPDATE the existing Draft PR — never a second PR), `gh pr ready <number>` (ADR-0006 compat: still ends
    at PR), ticket comment §5, notify §7.
- **Context:** `skills/do/reference/mode-sub-agents.md:138-255`; `skills/do/reference/finish.md:49-79,116-131`;
  `skills/do/reference/status-protocol.md`; `skills/do/reference/report-format.md`;
  `skills/do/agents/task-executor.md:1-8,150-173`; `skills/draft/reference/markup-format.md` (Task 1); PRD User
  Stories 10-15; `deprecated/fix/SKILL.md:264-273`.
- **Verify:** prettier clean; the file cites `task-executor.md`, `finish.md`, `markup-format.md`; contains
  `gh pr ready` and the `in_reply_to` reply call.

### Task 5: Wire the Draft execution rung into `do/SKILL.md`

- **Files:** `skills/do/SKILL.md:20-64` (edit)
- **Depends on:** Task 4
- **Scope:** M
- **What:** Add the input shape, router rung(s), and Modes-table row so drafts route to
  `reference/mode-draft-execution.md`.
- **How:** In **Input** add a bullet: a Draft PR URL, or a bare `<slug>` whose `.yoke/ai/<slug>/` records a Draft
  (draft execution). In **Router** add, ahead of the current issue-URL/slug rung (DD-4): `$ARGUMENTS` is a GitHub
  PR URL (contains `/pull/`, not `/issues/`) → Draft execution → read and follow
  `reference/mode-draft-execution.md`; and: `$ARGUMENTS` is a bare `<slug>` and `.yoke/ai/<slug>/<slug>-draft.md`
  exists → Draft execution. Keep first-match-wins; the `-plan.md` rung stays first among path forms. In **Modes**
  table add a **Draft execution** row: "Draft PR URL / drafted `<slug>` → implement the Markup (comments > markers >
  plan), reply in threads, flip the PR to ready."
- **Context:** `skills/do/SKILL.md:20-64`; `.yoke/context.md` do modes ("Draft execution" label); Task 4 file name.
- **Verify:** `grep -n "Draft execution" skills/do/SKILL.md` and `grep -n "mode-draft-execution" skills/do/SKILL.md`
  both present; prettier clean.

### Task 6: Add the draft-aware note to `finish.md` §3

- **Files:** `skills/do/reference/finish.md:49-79` (edit)
- **Depends on:** none
- **Scope:** S
- **What:** Teach the `pr` finish policy the two draft variants without disturbing the common path.
- **How:** Under the §3 `pr` bullet add a compact paragraph: for a `/draft` run, pass `--draft` to the pr-skill
  create call (the PR opens as a GitHub Draft PR); for a `/do` Draft execution the PR already exists — the pr
  mechanics UPDATE it (draft state preserved) and the run then flips it with `gh pr ready <number>` — never create
  a second PR. Note ADR-0006 compat explicitly: flipping to ready still ends the run at the PR.
- **Context:** `skills/do/reference/finish.md:49-79`; `skills/pr/SKILL.md:43,63,68`; ADR-0011.
- **Verify:** `grep -n "gh pr ready" skills/do/reference/finish.md` and `grep -n -- "--draft"` both present;
  prettier clean.

### Task 7: Write `docs/draft.md`

- **Files:** `docs/draft.md` (create)
- **Depends on:** Task 2, Task 3, Task 4
- **Scope:** M
- **What:** The long-form doc, table-styled like `docs/do.md`/`docs/pr.md`, carrying the `**Output:**` line
  sync-docs reads.
- **How:** Sections: intro (the optional marking step between grill and do); **Input** (same contract as `/do`);
  **Flow** (fresh: Plan → Mark → Draft PR; iteration: re-read comments → re-mark → reply); the draft→ready
  lifecycle across `/draft` and `/do`; an `**Output:**` line — Draft PR link(s) + `.yoke/ai/<slug>/<slug>-draft.md`
  \+ plan artifact; **Connections** (`/grill → /draft → PR review → /do → ready PR`). Mirror `docs/do.md` headings
  and tables.
- **Context:** `docs/do.md`; `docs/pr.md`; PRD Solution; Tasks 2-4 outputs.
- **Verify:** `grep -n "^\*\*Output:\*\*" docs/draft.md` present; prettier clean.

### Task 8: Add the Draft execution row to `docs/do.md`

- **Files:** `docs/do.md` (edit)
- **Depends on:** Task 5
- **Scope:** S
- **What:** Document the new mode in `do`'s long-form doc.
- **How:** Add a **Draft execution** row to the Modes table matching the SKILL.md wording; add a line in
  **Connections** noting `/draft` feeds `/do` a reviewed Draft PR that `/do` implements and flips to ready.
- **Context:** `docs/do.md` Modes + Connections sections; Task 5 wording.
- **Verify:** `grep -n "Draft execution" docs/do.md` present; prettier clean.

### Task 9: Add draft rows to `docs/notify.md`

- **Files:** `docs/notify.md` (edit)
- **Depends on:** Task 3
- **Scope:** S
- **What:** Record the `/draft` notification point in the trigger map.
- **How:** Add a row `draft | Finish | STAGE_COMPLETE | <slug>: Draft PR ready — Draft PR URL as payload` to the
  map table; note that a `/do` Draft execution reuses the existing `do | Finish | STAGE_COMPLETE` row when it flips
  the PR to ready, and a `/draft` iteration re-fires the draft STAGE_COMPLETE after pushing the redrawn Markup.
- **Context:** `docs/notify.md` map table; `finish.md` §7; Task 2 notify call.
- **Verify:** `grep -n "| draft" docs/notify.md` present; prettier clean.

### Task 10: Add `/draft` to `help/SKILL.md`

- **Files:** `skills/help/SKILL.md` (edit)
- **Depends on:** Task 3
- **Scope:** M
- **What:** List `/draft` in the help catalog and the Full cycle, as an optional step (no restructuring of
  grill → do → PR).
- **How:** Add a `### /draft` section (Input/Output/example, style of the neighboring `/do` block) in flow order
  between grill and do. In **Full cycle** add one optional line:
  `/yoke:draft <ticket | description>  # optional: mark the code, open a Draft PR to review before implementing`,
  positioned between grill and do, flagged optional. Do not alter the canonical grill → do → PR wording.
- **Context:** `skills/help/SKILL.md` (skill list + Full cycle); PRD Out of Scope (draft stays optional);
  `.yoke/context.md` Flow.
- **Verify:** `grep -n "draft" skills/help/SKILL.md` shows the new section + Full cycle line; prettier clean.

### Task 11: README mermaid + prose (non-sentinel)

- **Files:** `README.md` (edit — mermaid diagram + "How to use" prose only)
- **Depends on:** Task 3
- **Scope:** S
- **What:** Show the optional Draft step in the diagram and prose without touching the sentinel catalog table.
- **How:** In the mermaid add an optional `draft` node between `grill` and `do` on a dotted link (match the
  existing `-.->` syntax; keep the default `grill → do → pr → merge` path intact). In "How to use" add one
  sentence: `/yoke:draft` optionally projects the plan onto the code as a Draft PR to review before `/do`
  implements it. Do not edit anything between `<!-- yoke:skills:start -->` and `<!-- yoke:skills:end -->`.
- **Context:** `README.md` head; commit b47bbd3 (mermaid dotted-link syntax); PRD Solution.
- **Verify:** dotted-link syntax matches existing lines; sentinel block unchanged; prettier clean.

### Task 12: CLAUDE.md prose (non-sentinel)

- **Files:** `CLAUDE.md` (edit — "Implemented skills" prose only)
- **Depends on:** Task 3
- **Scope:** S
- **What:** Mention the optional `/draft` marking step in the "Implemented skills" prose paragraph.
- **How:** Extend the `/do`/`/merge` summary paragraph with one or two sentences: `/draft` is the optional marking
  step between grill and do — it projects the plan onto the code as Markup and opens a Draft PR for remote review;
  `/do` later implements the reviewed draft and flips it to ready. Do not edit the sentinel bullet list.
- **Context:** `CLAUDE.md` Implemented skills section; `.yoke/context.md` Draft + Flow.
- **Verify:** `grep -n "/draft" CLAUDE.md` shows the prose mention; sentinel block unchanged; prettier clean.

### Task 13: Regenerate the catalog (sync-docs counts + run sync)

- **Files:** `.claude/skills/sync-docs/SKILL.md` (edit); regenerate `README.md` sentinel table, `CLAUDE.md`
  sentinel bullets, `site/src/content/docs/skills/draft.mdx`
- **Depends on:** Task 3, Task 7, Task 11, Task 12
- **Scope:** M
- **What:** Update sync-docs' descriptive counts/list, then regenerate the catalog so `/draft` appears.
- **How:** In `.claude/skills/sync-docs/SKILL.md` bump the skill count (14 → 15) where stated and add `draft` to
  the enumerated list (alphabetical). Then perform the sync-docs regeneration per its SKILL.md (Phase 3/5): render
  `site/src/content/docs/skills/draft.mdx`, rewrite the sentinel blocks in `README.md` and `CLAUDE.md` — sentinel
  bytes only, preserving Task 11/12 prose. Prettier-write the changed files.
- **Context:** `.claude/skills/sync-docs/SKILL.md` + `.claude/skills/sync-docs/reference/sync-spec.md`; Task 3
  description text; Task 7 `**Output:**` line.
- **Verify:** README sentinel table has a `draft` row; CLAUDE.md sentinel list has a `/draft` bullet;
  `site/src/content/docs/skills/draft.mdx` exists; prose outside sentinels intact; `pnpm run format:check` clean.

### Task 14: Validation

- **Files:** —
- **Depends on:** all
- **Scope:** M
- **What:** Run every structural gate the PRD Testing Decisions name.
- **How:** `pnpm run format` then `pnpm run format:check`; JSON manifest sanity
  (`python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"`);
  frontmatter check `head -1 skills/*/SKILL.md` (every line `---`); yoke-validate conventions pass over
  `skills/draft/SKILL.md` and `skills/do/SKILL.md` (Strunk prose + plugin-dev structure); sync-docs drift check;
  DD-7 sanity: `grep -rn "TODO(yoke)" skills/ lib/` returns only intentional documentation occurrences under
  `skills/draft/reference/` and `skills/do/reference/mode-draft-execution.md`.
- **Context:** PRD Testing Decisions; repo `CLAUDE.md` Validation section.
- **Verify:** `pnpm run format:check` && manifest OK && no sync drift — all green.

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** 14 tasks with clear parallel groups in a single codebase; cross-referential skill texts benefit
  from the per-task review loop.
- **Order:**
  Group 1 (parallel): Task 1, Task 6
  ─── barrier ───
  Group 2 (parallel): Task 2, Task 4
  ─── barrier ───
  Group 3 (parallel): Task 3, Task 5
  ─── barrier ───
  Group 4 (parallel): Task 7, Task 8, Task 9, Task 10, Task 11, Task 12
  ─── barrier ───
  Group 5 (sequential): Task 13
  ─── barrier ───
  Group 6 (sequential): Task 14

## Verification

- grill → draft produces a Draft PR containing only Markers + compilable stubs (no implemented logic).
- Comment on the Draft PR → `/draft` re-run updates Markup and replies in threads.
- `/do <draft-PR-URL>` implements, replies in threads, leaves zero Markers (grep gate), flips the same PR to ready.
- A conflicting comment beats a Marker; an architecture-overturning comment stops with a question.
- Structural gates: `pnpm run format:check`, manifest JSON parse, SKILL.md frontmatter, catalog sync, no stray
  `TODO(yoke)` outside intentional docs.

## Materials

- PRD: `.yoke/ai/draft-marking-step/draft-marking-step-prd.md` (issue #32)
- ADR: `.yoke/adr/0011-draft-optional-marking-step.md`
- Glossary: `.yoke/context.md` (Draft, Flow, do modes)
- Video origin: https://www.youtube.com/watch?v=Aie0nYktsNA
