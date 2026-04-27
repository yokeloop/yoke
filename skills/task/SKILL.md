---
name: task
description: >-
  Draft a task file for AI implementation. Triggered when the user writes
  "create a task", "task from ticket", "draft a task", "prepare an implementation
  prompt", or passes a ticket URL / feature description.
---

# Draft a task for AI implementation

You are the orchestrator. Coordinate sub-agents and talk to the user.

Delegate codebase investigation through the Agent tool:

- Investigation → `agents/task-investigator.md`

You formulate the task; you do not implement it.

---

## Input

`$ARGUMENTS` contains one or both of:

- **Ticket URL** — GitHub Issues, YouTrack, Jira, etc.
- **Task text** — description, code snippets, links

---

## Phases

### Phase 1 — Parse

**1. Fetch the ticket content:**

- GitHub Issues → `gh issue view <url>`
- Other trackers → take the content from the user's text; use the URL only for the slug

**2. Extract materials from the input:**
Collect a separate list of:

- links (Figma, docs, API)
- paths to files and screenshots
- pasted code snippets
- external resources

Copy this list verbatim into the `Materials` section.

**3. Build the task slug** — identifier + English kebab-case description:

- `86-black-jack-page` — from GitHub issue #86
- `R2-50-user-id-to-db` — from YouTrack R2-50
- `fix-navbar-overflow` — no URL, text only

Rule: ID from the URL + 2–4 descriptive words. No URL — description only.

**4.** Extract `TICKET_ID` from the slug (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`).

**Transition:** slug and TICKET_ID determined, materials saved → Phase 2.

---

### Phase 2 — Investigate

**Launch task-investigator through the Agent tool.** The agent is defined in `agents/task-investigator.md`.

Prompt to the agent:

```
Investigate the codebase area for this task: [paste the ticket essence].

Find and document:
1. Entry points with file:line
2. Patterns to reuse (1-2 similar implementations)
3. Tests covering the area, or note their absence
4. Integration risks and fragile dependencies
5. Reusable utilities, components, or patterns
```

**Stop criteria — Investigate is done when:**

- [ ] Entry points are identified with line numbers
- [ ] Patterns to reuse are found with example files
- [ ] Tests for the touched area are listed, or you confirm their absence
- [ ] Risk zones are identified

If any item stays open, re-dispatch task-investigator with a narrower scope.

**Transition:** all four criteria closed → Phase 3.

---

### Phase 3 — Synthesize

**Apply the 5-dimension checklist to Phase 2 findings.** For each: one sentence of reasoning, then the formulation.

1. **Intent Clarity.** Will two developers read the Task and do the same thing? One verb per Task — concrete, not "improve" or "fix".
2. **Scope Boundaries.** What sits in scope and what stays explicitly out? Each Constraint maps to a concrete risk from Investigate (fragile file, similar code that must stay, dependency surface).
3. **Context Anchoring.** Cite paths and line numbers — `src/auth/middleware.ts:validateToken():89`, not "the auth module". Context has 4 subsections: Area architecture, Files to change, Patterns to reuse, Tests.
4. **Acceptance Criteria.** Write each Verification bullet as a command with expected result OR an observable behavior. Pull edge cases from Investigate findings.
5. **Reuse Opportunities.** For each requirement, find a partial existing solution. Record under Patterns to reuse with paths.

**Complexity:** trivial (1 file, ≤5 lines) / simple (1-2 files, clear scope) / medium (3-7 files, possible regressions) / complex (architecture, multiple layers, no tests, public API).

**If the task touches UI components, styles, or frontend work** (React, Vue, Svelte, CSS, Tailwind, animations, layouts, pages): read `reference/frontend-guide.md` and apply its checklists to the Requirements, Constraints, and Verification dimensions.

For deeper Bad/Good examples and anti-patterns, see `reference/synthesize-guide.md` — supplementary.

**Question validation:**

Re-read `$ARGUMENTS`. Drop questions the prompt already answers. Fold the user's decisions into Requirements/Constraints as facts.

**Interactive clarifications:**

Draft 3–7 clarifying questions about implementation decisions whose answer changes the Task.
Ask the user via AskUserQuestion in batches of 1–4 questions.

For each question:

- 2–4 answer options with explanations
- Recommended option first, labeled `(Recommended)`
- The user may pick "Other" for free-form input

After each batch, revise Requirements, Constraints, and Context. Fold the answers into the section wording.

Repeat until the user answers every question.

**Transition:** 5 dimensions applied, questions asked and answers folded in → Phase 4.

---

### Phase 4 — Write

**1.** `mkdir -p docs/ai/<task-slug>`

**2.** Write `docs/ai/<task-slug>/<task-slug>-task.md`:

```
# <Task title>

**Slug:** <task-slug>
**Ticket:** <URL or "—">
**Complexity:** <trivial | simple | medium | complex>
**Type:** <frontend | general>

## Task

<One sentence — what to do.>

## Context

### Area architecture
<Data flow, entry points, abstraction layers>

### Files to change
<Paths + lines — entry points for implementation>

### Patterns to reuse
<Similar implementations with paths — what to reuse>

### Tests
<Existing coverage, what to cover next>

## Requirements

1. <Concrete, verifiable requirement>
2. ...

## Constraints

- <What NOT to change>
- <Which approaches to avoid>
- <What not to break>

## Verification

- `<command>` → <expected result>
- <expected behavior>
- <edge cases>

## Materials

- [Description](url)
- `path/to/file`
```

**3. Self-check the prose** — re-read the file. Edit inline if any sentence violates:

- Active voice — "the agent reads the file"
- Positive form — "Add tests" (not "Don't forget tests")
- Concrete language — files, lines, function names
- No needless words
- Imperative mood

**4. Auto-commit the artifact.**

Check: is `docs/ai/` in `.gitignore`? If yes — tell the user and skip the commit.

Otherwise commit per the convention in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`:

```bash
git add docs/ai/<task-slug>/<task-slug>-task.md
git commit -m "TICKET docs(SLUG): add task definition"
```

Format: `TICKET docs(SLUG): add task definition` (NO colon after ticket).
Example: `#86 docs(86-black-jack-page): add task definition`.
Commit only the task artifact, no other files.

**Transition →** Phase 5.

---

### Phase 5 — Complete

Report the file path and task slug, then run the finishing loop.

Send a notification:
`bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill task --phase Complete --slug "$TASK_SLUG" --title "Task ready" --body "docs/ai/$TASK_SLUG/$TASK_SLUG-task.md"`

**Loop:**

Offer 3 options through AskUserQuestion:

1. **Run /yoke:plan (Recommended)** — auto-handoff to planning
2. **Review via revdiff** — interactive review of the task file
3. **Finish** — exit

**Handle the choice:**

- **Run /yoke:plan:** call the Skill tool with `/yoke:plan` and the argument `docs/ai/<task-slug>/<task-slug>-task.md`. Exit.
- **Review via revdiff:** After revdiff closes, continue with the following steps:
  1. Call the Skill tool with `/revdiff` and the argument `--only docs/ai/<task-slug>/<task-slug>-task.md`.
  2. If the Skill return is non-empty, apply the returned annotations to the task file and overwrite `docs/ai/<task-slug>/<task-slug>-task.md`. If the return is empty, skip this step.
  3. Return to the "Offer 3 options" step above.
     If the plugin is missing — print `Install the revdiff plugin:` followed by `  /plugin marketplace add umputun/revdiff` and `  /plugin install revdiff@umputun-revdiff`, then return to the "Offer 3 options" step above.
- **Finish:** report the file path. Exit.

---

## Rules

- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
- task-slug — English kebab-case
- One task — one file, no decomposition
- Write in active voice. Omit needless words. Name files and lines instead of abstractions.
