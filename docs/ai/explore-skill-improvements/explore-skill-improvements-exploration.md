# Exploration: tell me about the explore skill — can it currently create an issue or ticket?

**Date:** 2026-04-20
**Questions:** 2

---

## Q1: tell me about the explore skill — can it currently create an issue or ticket?

### Context

First question of the session. The user is thinking through the boundaries of the /yoke:explore feature set and wants
to understand whether the current implementation can create a GitHub issue or a ticket in another system through this
skill, or whether explore is strictly read-only. This is a prelude to the next question about improvements — the user
first confirms the current state.

### Answer

No, the `/yoke:explore` skill currently cannot create an issue or ticket. It is exclusively a read-only mode: codebase
research + Q&A, whose result is a local markdown log file, not a ticket in GitHub/Jira.

### Details

1. The explore-agent is read-only by design
   - `skills/explore/agents/explore-agent.md:6` explicitly restricts the tools:
     ```
     tools: Glob, Grep, LS, Read, Bash, WebSearch, WebFetch
     ```
   - No `Write`, no `Edit`. The rules (`skills/explore/agents/explore-agent.md:97`) state directly:
     `Read-only. Write and Edit are unavailable.`
   - Bash is needed only for `git log --oneline`, `wc -l`, and similar read operations (`explore-agent.md:40`).

2. The SKILL.md orchestrator — no ticket creation
   - `skills/explore/SKILL.md:32-38` describes three phases: Init → Loop (Q&A) → Finalize.
   - In Finalize (`SKILL.md:121-143`) the only action is dispatching `explore-log-writer`, which writes a
     local file.
   - The skill description (`SKILL.md:2-9`) says nothing about issue/ticket/GitHub.

3. The log-writer writes only to docs/ai
   - `skills/explore/agents/explore-log-writer.md:37` hardcodes the path:
     `EXPLORATION_LOG="docs/ai/{{SLUG}}/{{SLUG}}-exploration.md"`
   - The writer's tools are `Read, Write, Edit, Bash` (`explore-log-writer.md:5`), but rule
     `explore-log-writer.md:85` says: `Do not commit — only create/update the file.` So there isn't even a commit, let
     alone `gh issue create`.

4. Across the entire yoke codebase a search for `gh issue create` is empty
   - `grep -i "gh issue"` over `skills/` finds only a single mention in `skills/task/SKILL.md:37` —
     `GitHub Issues → gh issue view <url>`, and that reads an existing ticket in the `/yoke:task` skill, not
     creation.
   - There is no `gh issue create` anywhere in yoke.

5. How the neighboring skills differ
   - `/yoke:task` — reads a ticket (issue/URL) and turns it into a task file; it does not create issues.
   - `/yoke:pr` — creates a Pull Request via `gh pr create`, but a PR, not an issue.
   - `/yoke:explore` — does not touch external systems at all.

What you can do today if you need a ticket from /explore:

- Save the session (Phase 3 → `docs/ai/<slug>/<slug>-exploration.md`) and manually copy the Summary/Options into
  `gh issue create`.
- Use the log file as input for `/yoke:task` if the goal is an implementation task rather than a discussion ticket.

### Key files

- `skills/explore/agents/explore-agent.md:6` — the agent's tool list: Glob, Grep, LS, Read, Bash,
  WebSearch, WebFetch; no Write/Edit.
- `skills/explore/agents/explore-agent.md:97` — explicit rule "Read-only. Write and Edit are unavailable."
- `skills/explore/SKILL.md:121-143` — the Finalize phase: the only side effect is a local md file via
  log-writer.
- `skills/explore/agents/explore-log-writer.md:37` — hardcoded path `docs/ai/<SLUG>/<SLUG>-exploration.md`.
- `skills/explore/agents/explore-log-writer.md:85` — rule "Do not commit — only create/update the file."
- `skills/task/SKILL.md:37` — the only mention of `gh issue` in all of yoke — and even that is just `gh issue view`
  (a read).

---

## Q2: The user wants to improve explore in two ways — (1) creating an issue/ticket based on the session's accumulated Q&A, (2) removing the extra "Ask another question" click in the menu after every answer — they want to type the next question right away without an intermediate step. Brainstorm options for both improvements. (brainstorm)

### Context

Continuation after Q1, which established that the current explore cannot create issues. Now the user formulates the
desired improvement: (1) add issue creation from session material, (2) remove the UX friction in the Loop, where after
each answer AskUserQuestion forces a "Ask another question" selection before input. The goal of the question is to get a
set of options and guidance on integration points (which files/phases) before turning this into a plan or task.

### Answer

`/yoke:explore` currently cannot create issues — the `explore-agent` is read-only
(`skills/explore/agents/explore-agent.md:6`), and `explore-log-writer` only writes markdown and does not commit
(`skills/explore/agents/explore-log-writer.md:85`). The closest analog for writing via `gh` is `/yoke:pr`, which
calls `gh pr create` directly in the orchestrator (`skills/pr/SKILL.md:100`). Each question has 3-4 implementation
options; the key fork is whether to keep an intermediate menu or to change the "orchestrator asks" model to
"orchestrator just waits for new input".

### Details

Current state of explore:

- Phase 2 — the loop (`SKILL.md:60-117`). Step 2e (`SKILL.md:105-111`) — `AskUserQuestion` with the menu
  `{Ask another question / Save and finish / Continue without saving}`. That's exactly where the extra click is.
- Finalization (`SKILL.md:121-143`) goes through `AskUserQuestion` for the slug + a finishing pass by
  `explore-log-writer`. After Finalize there is no "create issue" step — the only artifact is a file.
- `docs/explore.md:23` lists a Phase 4 Complete with
  `AskUserQuestion: another question / create a task via /yoke:task / finish`, but it is not in `SKILL.md` — that is
  already a discrepancy between the doc and the skill's code (indicating that Phase 4 was originally planned).

Patterns for writing via gh in yoke:

- `/yoke:pr` — the orchestrator itself calls `gh pr create --title --body --base [--draft]`
  (`skills/pr/SKILL.md:99-101`), the body is generated by `pr-body-generator`
  (`skills/pr/agents/pr-body-generator.md`), and the data is gathered by `pr-data-collector` (which has
  `gh auth status` and label listing, `skills/pr/agents/pr-data-collector.md:47-112`). This is a ready-made template for
  `gh issue create`.
- `/yoke:review` calls `gh api --method POST repos/{owner}/{repo}/issues/{number}/comments` to publish
  comments (`skills/review/SKILL.md:140-142`) — showing that yoke already has the pattern "orchestrator publishes to GH
  via gh api".
- `/yoke:task` reads an issue (`gh issue view`, `skills/task/SKILL.md:37`), but does not create one — i.e. an explicit
  gap in the other direction.

Patterns for "free-form next input":

- Nowhere in yoke is there a between-phases model of "just wait for the user's next message without a menu". Everywhere
  it's either `AskUserQuestion` with options, or end-to-end work without stops.
- Exceptions: `skills/bootstrap/SKILL.md:290` — "wait for the user's signal" after Review-and-edit, but that lacks a
  formal mechanism.
- `skills/explore/SKILL.md:151` already contains the rule "Wait for questions from the user", but immediately before it
  step 2e presents a menu — a contradiction.
- In `skills/task/SKILL.md:152` and `skills/plan/SKILL.md:162` the "Other for free-form input" pattern is built into
  AskUserQuestion — a compromise, but not a full solution.

### Options

- [ ] **A1. New Phase 4 "Create issue?" after Finalize (symmetric with the /yoke:task → /yoke:plan handoff)** —
      After `explore-log-writer` has written the file, the orchestrator asks via `AskUserQuestion`:
      `{Create GitHub issue / Handoff to /yoke:task / Finish}`. On "Create issue" the orchestrator (a)
      checks `gh auth status` and `gh repo view`, (b) calls a new agent `explore-issue-writer` (haiku),
      which synthesizes title+body from `QA_LOG` + `EXPLORATION_SUMMARY` (the way `pr-body-generator` does it
      for PRs), (c) calls `gh issue create --title --body [--label exploration]`, (d) prints the URL. Pros:
      isomorphic to the `/pr` pattern, minimally invasive, doesn't touch the Loop. Cons: one more click at the end,
      and the issue is always built from the whole session at once (you can't say "for this question — file an issue").
      Integration: SKILL.md Phase 3 →
      add a Phase 4 "Issue", a new agent `skills/explore/agents/explore-issue-writer.md` modeled on
      `skills/pr/agents/pr-body-generator.md`. Evidence: `skills/pr/SKILL.md:99-101` (gh pr create in the
      orchestrator), `skills/task/SKILL.md:263-273` (handoff-menu pattern after the main work).

- [ ] **A2. Per-question "issue from this Q&A" flag** — In step 2e the menu expands to
      `{Next question / Save and finish / Create issue from last answer / Continue without saving}`. If
      the user clicks "Create issue from last answer", the orchestrator takes the last QA_LOG record +
      EXPLORATION_SUMMARY as context, passes it to `explore-issue-writer`, creates the issue, and returns to 2a.
      Pros: targeted issues for specific findings (a brainstorm with options → an issue with options as checkboxes).
      Cons: grows the menu to 4 options, complicates state (you have to remember an issue was already filed from Q3 to
      avoid duplicating). Integration: `skills/explore/SKILL.md:107-111` (step 2e) + a new agent. Evidence:
      `skills/review/SKILL.md:134-144` (the "publish findings as per-issue GH comments" pattern).

- [ ] **A3. Opt-in slash command /yoke:explore-issue \<slug\> as a separate skill** — Leave `/yoke:explore` as is
      (file only), but add a separate skill `/yoke:explore-issue <slug>` that reads the finished
      `docs/ai/<slug>/<slug>-exploration.md`, synthesizes an issue, and creates it via `gh issue create`. Pros:
      zero load on the explore loop, can be run weeks after the session, a clean separation of
      responsibilities. Cons: an extra command in the lineup, the user has to remember the slug. Integration: a new
      `skills/explore-issue/SKILL.md`, reusing `reference/exploration-log-format.md` as the input schema.
      Evidence: `skills/task/SKILL.md:37` (the symmetric "separate per-direction I/O skill" pattern).

- [ ] **A4. Inline commands inside the Loop — "/issue" as a user intent** — Instead of the menu in 2e, in the
      free-form field the user can type a special command — the first line starts with `/issue <title>` → the
      orchestrator recognizes it as a signal "create an issue from the previous Q&A" (not a new question). The rest of
      the text is the body/clarification for the issue. Pros: zero clicks, works in tandem with option B2/B3 (free-form
      input). Cons: a hidden API, needs documentation, easy to mistype the syntax. Integration: extend step 2a in
      `SKILL.md:64-71` — parse intent before sending to the agent. Evidence: `skills/fix/SKILL.md:36`
      (parsing $ARGUMENTS for a pull/...#discussion_r... URL as an intent switch — a similar approach).

- [ ] **B1. Default "Ask another question" option + auto-continue** — Keep AskUserQuestion in 2e, but
      mark the "Ask another question" option (Recommended) and embed an explicit instruction for the orchestrator:
      "After showing the answer, if the user's next message is not an explicit save/finish word — treat it as a new
      question, skipping the menu". The menu shows only on explicit completion signals. Pros: minimal
      change in SKILL.md, preserves the Save and finish mechanism via a stop-word. Cons: the stop-word rules must be
      enumerated explicitly (stop, done, save, finish), internationalized (Russian/English), and it's
      fragile — it can trigger falsely. Integration: rewrite 2e (`SKILL.md:105-112`) into a rules section 2f.
      Evidence: `skills/bootstrap/SKILL.md:290` ("wait for the user's signal" — the closest precedent, but without
      formal stop-words).

- [ ] **B2. Remove step 2e, use free-form + an escape command (recommended)** — Fully drop
      AskUserQuestion from the Loop. After an answer, the orchestrator simply prints the result and returns to
      waiting for the user's next message (as in a normal chat mode). For Save and finish — a
      special command: the user types /save or /done, or just an empty message. Pros: the most
      natural flow, zero clicks, consistent with the spirit of "Wait for questions from the user"
      (`SKILL.md:151`). Cons: the user needs to know the escape command; the Claude Code orchestrator does not always
      handle "do nothing and wait" correctly without AskUserQuestion — surprises in the runner are possible.
      Integration: remove 2e, rewrite 2f into "next message → 2a, message starting with /save or /done →
      Phase 3". Add an explicit rule "do not invoke AskUserQuestion in the Loop, only in Init and Finalize".
      Evidence: `skills/explore/SKILL.md:151` (the rule is already declared, but 2e contradicts it),
      `skills/fix/SKILL.md:280` (No stops. Work through to the end without confirmations between phases — a
      precedent for removing intermediate confirmations).

- [ ] **B3. Hybrid — first question via AskUserQuestion, free-form afterward** — On the first turn
      (ITERATION == 0) show the menu as it is now, to convey the instruction "type the next question in chat; to
      save — type /save". From the second turn on — B2 mode without a menu. Pros: a baseline for teaching the
      user + zero clicks over time. Cons: two behavior models in one loop, harder to describe
      in SKILL.md. Integration: in `SKILL.md:105` a condition `if ITERATION == 0 → AskUserQuestion, else → free-form`.
      Evidence: `skills/task/SKILL.md:142-159` (the progressive clarifying-questions pattern in batches 1-4 with a
      Requirements revision between batches).

- [ ] **B4. Periodic checkpoint instead of a per-answer menu** — The 2e menu becomes a checkpoint every N
      questions (for example, N=5 or on the 2f warning at 20+ questions). Between them — pure free-form. Pros: a
      compromise between B1 and B2 — the user still occasionally sees explicit control, but not on every answer.
      Cons: you have to pick N (a magic number), or the user doesn't know when the menu will pop up. Integration:
      merge the logic of 2e and 2f (`SKILL.md:105-117`), add a counter. Evidence: `SKILL.md:114-115` (2f already
      contains a threshold-warning at 20 questions — extending it to a checkpoint is logical).

- [ ] **Other:** \_\_\_

### Key files

- `skills/explore/SKILL.md:60-117` — the Loop phase, where step 2e with the extra menu and 2f with the warning live
- `skills/explore/SKILL.md:121-143` — the Finalize phase, where "Create issue" would be integrated (A1)
- `skills/explore/SKILL.md:151` — the "Wait for questions from the user" rule, which contradicts 2e
- `skills/explore/agents/explore-agent.md:6` — read-only tools; you can't add Write/Bash without a redesign
- `skills/explore/agents/explore-log-writer.md:85` — the "Do not commit" rule; symmetrically it will need to be set for
  the issue-writer
- `skills/pr/SKILL.md:99-101` — the gh pr create template in the orchestrator (the basis for gh issue create in A1)
- `skills/pr/agents/pr-body-generator.md` — the body-synthesizer agent template (the basis for explore-issue-writer)
- `skills/pr/agents/pr-data-collector.md:47-112` — gh auth status, label listing — the checks needed for the
  issue path
- `skills/task/SKILL.md:37` — the only current use of gh issue view in yoke
- `skills/task/SKILL.md:263-273` — the handoff-menu pattern at the end of a skill, a template for Phase 4 in A1
- `skills/review/SKILL.md:140-142` — the precedent for gh api --method POST .../issues/.../comments (an alternative
  low-level path)
- `skills/fix/SKILL.md:36,280` — the intent-parsing pattern from $ARGUMENTS (for A4) and the "No stops" rule (for B2)
- `skills/explore/reference/exploration-log-format.md` — the markdown log format from which the issue-writer would
  pull material
- `docs/explore.md:23` — a discrepancy: it mentions a Phase 4 Complete with a menu that isn't in SKILL.md (Phase 4
  was originally planned)

---

## Summary

The session established that the current `/yoke:explore` is strictly read-only: `explore-agent` has no Write/Edit,
`explore-log-writer` writes only a local `docs/ai/<slug>/<slug>-exploration.md` without committing, and across all of
yoke there is not a single `gh issue create` call. For the "create an issue from the session" improvement, the cleanest
path is A1 (a new Phase 4 "Create issue?" after Finalize, modeled on `/yoke:pr` with `gh pr create` and a separate
body-generator), optionally complemented by A2 for per-question granularity. For "remove the extra click", the
healthiest options are B2 (fully remove AskUserQuestion from the Loop, relying on `/save` as an escape) or B3
(hybrid, menu only on the first turn); B1 is fragile due to the internationalization of stop-words. Also found a
discrepancy between `docs/explore.md:23` and `SKILL.md` — Phase 4 was originally planned but not implemented,
which lowers the risk of introducing A1 as "restoring the intended behavior".
