---
name: issues
description: >-
  Breaks a plan, spec, or PRD into independently-grabbable GitHub issues using
  vertical slices (tracer bullets), publishes them in dependency order, and
  saves a local index in .yoke/ai. Activates when the user writes "issues",
  "break into issues", "create tickets", "split into tasks",
  "decompose into issues", "make implementation tickets", "tracer bullets".
---

# Issues

Break a plan into independently-grabbable issues using vertical slices (tracer bullets). Each slice cuts end-to-end through every layer, so a completed one is demoable or verifiable on its own.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes an issue reference (issue number, URL, or path) as an argument, fetch it (`gh issue view <ref>` for GitHub) and read its full body and comments. When the path points to a PRD artifact (`<slug>-prd.md`), also extract any `**Tracking:** <URL>` line under the H1 — that URL marks the parent for sub-issue linking.

### 2. Explore the codebase (skip if already explored this session)

If the codebase has not been explored this session, explore it now to understand its current state. Follow the domain-doc consumer rules in `${CLAUDE_PLUGIN_ROOT}/skills/grill-docs/reference/domain-docs.md`: read `.yoke/context.md` and relevant `.yoke/adr/`, give issue titles and descriptions the glossary's vocabulary, and flag any ADR a slice contradicts.

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

### 4. Confirm the breakdown

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Granularity, dependency order, and HITL/AFK marking are the skill's own job — decide them and show the result, do not interview the user slice by slice. Publishing creates real GitHub issues, so gate it with a single approval: ask once via AskUserQuestion — **"Publish these N issues, or tell me what to change?"** with **Publish (Recommended)** first. Apply any requested edits in one pass, then publish. No multi-question loop.

### 5. Publish

Publish in dependency order (blockers first) to reference real issue identifiers in the "Blocked by" field. Follow `reference/github-issues.md` for the `gh` conventions and triage labels.

Order the slices so every blocker is created before the slices that depend on it. For each slice, in that order: write its body (the `<issue-template>` below) to a file, substitute the real issue numbers of its blockers into the "Blocked by" section, then create it:

```bash
gh issue create --title "<slice title>" --body-file <slice body file>
```

Label AFK slices `ready-for-agent` and HITL slices `ready-for-human` (per the reference; create a label if the repo lacks it, unless the user objects). Capture each returned issue number for its dependents to cite.

Once each child exists, run two best-effort follow-ups per the reference: set its type to `Task` (per "Issue types"; leave it untyped and warn if unavailable), and — if a parent issue is known (from the input argument or from a `**Tracking:** <URL>` line in a PRD artifact) — link the child as a sub-issue of the parent (per "Sub-issues"; leave it unlinked and warn if unavailable). The textual `## Parent` section in the issue body remains the human-readable fallback.

Build the slug as in `/yoke:prd` — an English kebab-case description, prefixed with a ticket id if one exists; reuse the parent PRD/issue's slug when the source was one, so `<slug>-prd.md` and `<slug>-issues.md` sit together. Save a local index to `.yoke/ai/<slug>/<slug>-issues.md` (`mkdir -p .yoke/ai/<slug>` first) listing every slice: title, type, blocked-by, the created issue URL, and its body.

If `gh` is not authenticated or there is no GitHub remote, skip publishing, write the full breakdown to the local index, and tell the user.

Do NOT close or modify any parent issue.

<issue-template>
## Parent

A reference to the parent issue (if there is one, otherwise omit this section).

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

Avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it here and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- A reference to the blocking ticket (if any)

Or "None - can start immediately" if no blockers.

</issue-template>

## Rules

- Vertical slices, not horizontal layers. Prefer many thin slices.
- Publish in dependency order so "Blocked by" can reference real issue numbers.
- Use the project's domain glossary and respect ADRs. Pair with `/yoke:prd` upstream.
- Language: match the conversation language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
