# Update documentation — implementation plan

**Task:** `docs/ai/8-update-documentation/8-update-documentation-task.md`
**Complexity:** simple
**Mode:** sub-agents
**Parallel:** mixed

## Design decisions

### DD-1: Decompose into 4 work tasks + 1 validation

**Decision:** five tasks total — T1 renames the skill, T2 restructures the README, T3 updates cross-references, T4 deletes the PNG, T5 validates.
**Rationale:** each commit stays atomic and reviewable. T1 isolates the rename so `git` records similarity. T2 bundles every README structural edit because they touch the same file region; splitting them rebases anchor strings against intermediate states for no isolation gain. T3 sweeps a one-liner; T4 runs a single `git rm`.
**Alternative:** five work tasks (mermaid separated from restructure) — rejected, both edit the README header window. Three work tasks (rename + cross-refs as one) — rejected, hides the `git mv` inside an unrelated diff.

### DD-2: Rename the skill before updating cross-references

**Decision:** Group 1 runs T1 (rename). Group 2 runs T3 (cross-refs) after T1 completes.
**Rationale:** `README.md` and `CLAUDE.md` link to `docs/help.md` and `/yoke:help`; those targets must exist on disk before the references point at them.
**Alternative:** swap the order — rejected, leaves a window where every link breaks.

### DD-3: Use `git mv` for the rename

**Decision:** run `git mv skills/hi skills/help` and `git mv docs/hi.md docs/help.md`. Edit only the `skills/help/SKILL.md` frontmatter; leave the body and `docs/help.md` body unchanged where possible.
**Rationale:** Git's rename detection needs similarity above 50%. Frontmatter-only edits preserve detection; `git log --follow` keeps the skill's history.
**Alternative:** delete + create — rejected, breaks blame on the skill body.

### DD-4: Edit `README.md` with anchor strings, not line numbers

**Decision:** every README edit in T2 and T3 uses unique anchor substrings via the `Edit` tool.
**Rationale:** T2 makes four sequential edits to one file. After each edit, line numbers shift; anchor strings stay valid. Order — top-down or bottom-up — then no longer matters.
**Alternative:** track shifting line numbers manually — rejected, fragile.

### DD-5: Mermaid diagram covers the pipeline plus a utility subgraph

**Decision:** `flowchart LR` with two clusters — the pipeline (`task → plan → do → review → gca → gp → pr`, plus a `fix` self-loop on `do`) and a utility subgraph (`gst`, `explore`, `bootstrap`, `help`) with no edges into the pipeline.
**Rationale:** the task spec names the exact node set. The "Full cycle" snippet at `README.md:166-178` is the source of truth for pipeline order. Utility skills are orthogonal helpers, so they sit in a labelled subgraph.
**Alternative:** pipeline only — rejected, the spec asks for utilities. Pipeline + edges into utilities — rejected, the relationship is not procedural.

### DD-6: Mermaid block uses the `mermaid` fence

**Decision:** open the block with three backticks followed by `mermaid` (not `mmd`).
**Rationale:** GitHub renders only the `mermaid` language tag.

### DD-7: "How to use" content shape — three commands plus pointer

**Decision:** `## How to use` lists `/yoke:help`, `/yoke:bootstrap`, and `/yoke:task <ticket>` as the entry-point trio, then a one-line pointer "See **Full cycle** below for the complete pipeline."
**Rationale:** the task spec calls for a "short quick-start" with these three commands. The pointer satisfies the constraint that `## Full cycle` stays in place.
**Alternative:** wider walkthrough — rejected, duplicates `## Full cycle`.

### DD-8: Help skill description leads with help/usage triggers

**Decision:** the new `description:` lists `"help"`, `"how do I use yoke"`, `"how to use"`, `"what skills are available"` first; it keeps `"hi"`, `"hello"`, `"where do I start"` as secondary triggers.
**Rationale:** `/help` is the canonical name; the lead triggers must match the skill identity. Greeting triggers preserve discovery for users who start with "hi".

### DD-9: Stage `git mv` before editing the renamed file

**Decision:** in T1, run `git mv` first, then edit `skills/help/SKILL.md` at the new path.
**Rationale:** Git records the rename when the move stages before the edit, keeping similarity detection above the threshold. Edit-then-move risks Git treating the change as delete + add.

### DD-10: `docs/pi-adaptation.md:998` is historical

**Decision:** treat `docs/pi-adaptation.md:998` as historical alongside `docs/pi-yoke-repo-plan.md`. No edit.
**Rationale:** the file is a Russian adaptation log paralleling `pi-yoke-repo-plan.md`. The task constraint excludes that family of planning notes from the cross-reference sweep.

## Tasks

### Task 1: Rename `/hi` skill to `/help`

- **Files:** `skills/hi/SKILL.md` → `skills/help/SKILL.md` (move + frontmatter edit), `docs/hi.md` → `docs/help.md` (move + title/prose edit)
- **Depends on:** none
- **Scope:** S
- **What:** rename the skill directory and its companion doc; edit only the frontmatter and the title — keep the skill body unchanged so Git records a rename.
- **How:**
  1. `git mv skills/hi skills/help`
  2. `git mv docs/hi.md docs/help.md`
  3. Edit `skills/help/SKILL.md` frontmatter: change `name: hi` to `name: help`. Replace the `description:` value with: `Greets the user and explains how to use yoke. Activate when the user writes "help", "how do I use yoke", "how to use", "what skills are available", "hi", "hello", "where do I start", or on first contact with yoke.`
  4. Edit `docs/help.md`: change `# Skill /hi` to `# Skill /help`. Update fenced examples that show `/yoke:hi` to `/yoke:help`. Reframe prose that refers to `/hi` or "welcome skill" as "help skill".
- **Context:** `skills/hi/SKILL.md:1-3` (current frontmatter), `docs/hi.md:1-40` (current body).
- **Verify:** `head -1 skills/help/SKILL.md` prints `---`; `ls skills/help/SKILL.md docs/help.md` lists both; `ls skills/hi 2>/dev/null` and `ls docs/hi.md 2>/dev/null` print nothing; `git status` shows two renames.

### Task 2: Restructure README.md (mermaid, Installation up, How to use, drop References)

- **Files:** `README.md`
- **Depends on:** none
- **Scope:** M
- **What:** replace the PNG with a mermaid diagram, lift `## Installation` to the top of the document, insert a new `## How to use` section, and delete `## References`. Leave `## Full cycle` (current lines 166-178) and `## Interactive review (revdiff)` (current 274-323) untouched.
- **How:**
  1. Replace the line `![yoke — command and workflow overview](yoke.png)` with a fenced `mermaid` block:

     ```mermaid
     flowchart LR
       task --> plan --> do --> review --> gca --> gp --> pr
       do --> fix
       fix --> do
       subgraph utility
         gst
         explore
         bootstrap
         help
       end
     ```
  2. Cut the `## Installation` block (heading plus the fenced bash block) and insert it directly after the inspirations bullet list (after the `anthropics/claude-plugins-official` line) and before `## Skills`.
  3. Insert a new section directly after `## Installation`:

     ```markdown
     ## How to use

     After install, start with the help skill, prepare the project, then run the pipeline:

     ```
     /yoke:help               # overview of skills
     /yoke:bootstrap          # detect stack, generate CLAUDE.md
     /yoke:task <ticket>      # define the first task
     ```

     See **Full cycle** below for the complete pipeline.
     ```
  4. Delete the `## References` section (current lines 325-329) — heading and three list items.
- **Context:** `README.md:1-12` (header and inspirations), `README.md:166-178` (`## Full cycle`, source for the diagram), `README.md:243-252` (`## Installation`), `README.md:325-329` (`## References`), `.claude/skills/yoke-create/SKILL.md:136-143` (mermaid style example).
- **Verify:** `pnpm run format:check` passes on `README.md`; `grep -n "yoke.png" README.md` empty; `grep -n "superpowers-lab" README.md` empty; `grep -n "## Installation" README.md` returns one line above `## Skills`; `grep -n "## How to use" README.md` returns one line; `grep -nc "## Full cycle" README.md` is 1.

### Task 3: Update `/hi` cross-references to `/help`

- **Files:** `README.md` (skill section ~126-132 and tree line 192), `CLAUDE.md` (line 71), `.claude/skills/yoke-create/SKILL.md` (line 367)
- **Depends on:** Task 1, Task 2
- **Scope:** S
- **What:** rewrite every live reference to the renamed skill so links resolve and the skill catalog matches reality.
- **How:**
  1. In the `README.md` skill section: change the heading `### /hi — skills overview` to `### /help — usage guide`; rewrite the description sentence to "Help skill — explains how to use yoke, lists available skills, recommended workflow."; update the link `[Details →](docs/hi.md)` to `[Details →](docs/help.md)`; change the fenced example `/yoke:hi` to `/yoke:help`.
  2. In the `README.md` Structure tree (line ~192): change `│   ├── hi/                  # welcome and skills overview` to `│   ├── help/                # how to use yoke`.
  3. `CLAUDE.md:71`: change `` - `/hi` — welcome and overview of available skills `` to `` - `/help` — how to use yoke and overview of available skills ``.
  4. `.claude/skills/yoke-create/SKILL.md:367`: change `Add a section for the new skill in README.md before \`### /hi\`.` to `Add a section for the new skill in README.md before \`### /help\`.`
- **Context:** `README.md:126-132,192`, `CLAUDE.md:71`, `.claude/skills/yoke-create/SKILL.md:367`.
- **Verify:** `grep -rn "/hi\b" README.md CLAUDE.md skills/ .claude/skills/` matches nothing (the rename leaves no `/hi` outside historical paths); `grep -n "docs/hi.md" README.md CLAUDE.md` empty; `grep -n "### /help" README.md` returns one line.

### Task 4: Delete `yoke.png`

- **Files:** `yoke.png` (remove)
- **Depends on:** Task 2
- **Scope:** S
- **What:** drop the 1.1 MB binary now that the mermaid block has replaced its only reference.
- **How:** `git rm yoke.png`.
- **Context:** `README.md:3` after Task 2 (no longer references `yoke.png`).
- **Verify:** `ls yoke.png 2>/dev/null` empty; `git grep -n "yoke.png"` matches only inside `docs/pi-yoke-repo-plan.md` (historical) — no live references remain in `README.md` or any other tracked location outside the historical doc.

### Task 5: Validation

- **Files:** —
- **Depends on:** Task 3, Task 4
- **Scope:** S
- **What:** confirm formatting, frontmatter, file presence and absence, and that no live `/hi` or `yoke.png` references remain.
- **How:** run the verification commands sequentially; format the workspace before checking so Husky's auto-format does not surprise the next commit.
- **Context:** —
- **Verify:**
  - `pnpm run format` then `pnpm run format:check` — both exit 0
  - `head -1 skills/*/SKILL.md` — every line is `---`
  - `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json'))"` — exits 0
  - `ls skills/help/SKILL.md docs/help.md` — both listed
  - `ls skills/hi 2>/dev/null; ls docs/hi.md 2>/dev/null; ls yoke.png 2>/dev/null` — empty
  - `grep -rn "/hi\b" README.md CLAUDE.md skills/ .claude/skills/` — no matches
  - `grep -n "yoke.png\|superpowers-lab" README.md` — no matches
  - `git grep -n "skills/hi\b" -- ':!docs/ai' ':!docs/pi-*.md' ':!docs/skill-optimization-plan.md'` — no matches

## Execution

- **Mode:** sub-agents
- **Parallel:** mixed
- **Reasoning:** T1 and T2 touch disjoint paths and run in parallel; T3 needs the renamed targets and the restructured README; T4 needs the mermaid block in place; T3 and T4 share no files and run in parallel; T5 closes the barrier.
- **Order:**
  Group 1 (parallel): Task 1, Task 2
  ─── barrier ───
  Group 2 (parallel): Task 3, Task 4
  ─── barrier ───
  Group 3 (sequential): Task 5

## Verification

- `pnpm run format:check` — passes on every changed file.
- `head -1 skills/help/SKILL.md` — prints `---`.
- `ls skills/hi 2>/dev/null` — empty (directory removed); `ls skills/help/SKILL.md` — exists.
- `ls docs/hi.md 2>/dev/null` — empty; `ls docs/help.md` — exists.
- `ls yoke.png 2>/dev/null` — empty (file removed).
- `grep -rn "/hi" README.md CLAUDE.md skills/ .claude/skills/` — no matches outside historical `docs/ai/*` and `docs/pi-*.md` / `docs/skill-optimization-plan.md`.
- `grep -n "yoke.png" README.md` — no matches.
- `grep -n "superpowers-lab" README.md` — no matches.
- Open `README.md` on GitHub: the mermaid block renders as a flowchart; `## Installation` precedes `## How to use`; `## Skills` follows; `## References` is gone.
- `claude --plugin-dir .` followed by `/yoke:help` — prints the welcome content.
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json'))"` — exits 0.

## Materials

- [GitHub Issue #8](https://github.com/yokeloop/yoke/issues/8)
- `README.md` — primary edit target
- `skills/hi/SKILL.md` — source content for the new `/help`
- `docs/hi.md` — companion doc to rename
- `yoke.png` — file to delete
- `CLAUDE.md` — references `/hi` at line 71
- `.claude/skills/yoke-create/SKILL.md` — references `/hi` at line 367
- `skills/gst/SKILL.md` — frontmatter pattern reference
- `.prettierrc.json` — formatter config
