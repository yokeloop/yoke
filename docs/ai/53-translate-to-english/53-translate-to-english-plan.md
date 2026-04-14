# Translate sp plugin content to English — implementation plan

**Task:** docs/ai/53-translate-to-english/53-translate-to-english-task.md
**Complexity:** complex
**Mode:** sub-agents
**Parallel:** true

## Design decisions

### DD-1: Anchor-first execution with explicit glossary

**Решение:** Translate the task+plan skill family first as a single commit (Task 1), then extract a trigger-phrase and tone glossary from its output (Task 2), and only then dispatch the remaining 11 family translations in parallel using that glossary as a reference.

**Обоснование:** Explorer findings identify tone drift across parallel agents as the primary batching risk. The task+plan nucleus contains both the longest orchestrator prompts (`skills/task/SKILL.md` 292 lines, `skills/plan/SKILL.md` 311 lines) and the R2/R3 coupled field-label renames, so it exercises every translation decision (imperative register, section headers, frontmatter descriptions, embedded strings, field labels). Using it as a voice anchor gives every downstream agent a concrete reference.

**Альтернатива:** Inline single-agent translation — rejected: 12 families × ~4,400 lines overflows a single agent's context and forfeits the available parallelism. All-sequential sub-agents — rejected: wastes the disjoint-path parallelism identified by the explorer (no cross-task file overlap except the R2/R3 nucleus which is already collapsed into Task 1).

### DD-2: Collapse coupled files into a single commit (Task 1)

**Решение:** Bundle 15 files spanning the `/task` and `/plan` skill families into Task 1: `skills/task/SKILL.md` + 2 agents + 3 references + 2 examples + `skills/plan/SKILL.md` + 3 agents + 2 references + 2 examples.

**Обоснование:** The `**Сложность:**` → `**Complexity:**` rename (R2) spans task template and plan extraction logic (`skills/plan/SKILL.md:41`), and the `**Решение:**/**Обоснование:**/**Альтернатива:**` → `**Decision:**/**Rationale:**/**Alternative:**` rename (R3) spans plan-format.md, plan examples, and plan-designer agent. Any split leaves the repo in a state where producers and consumers disagree on field labels, breaking a live extraction at `skills/plan/SKILL.md:41`.

**Альтернатива:** Separate task/ and plan/ tasks — rejected: forces a broken intermediate commit where a renamed template is read by an old extractor.

### DD-3: Glossary as an explicit artifact, not implicit reference

**Решение:** Task 2 reads Task 1 output and writes `docs/ai/53-translate-to-english/glossary.md` with canonical translations for recurring tokens: section headers (`Фаза`→`Phase`, `Вход`→`Input`, `Правила`→`Rules`, `Архитектура области`→`Area architecture`, `Файлы для изменения`→`Files to change`, `Паттерны для повторения`→`Patterns to reuse`, `Тесты`→`Tests`, `Материалы`→`Materials`), imperative phrases (`Решай, не спрашивай`→`Decide, don't ask`, `Ты — оркестратор`→`You are the orchestrator`), and the new R5 rule text. Tasks 3–13 receive the glossary path in their prompt.

**Обоснование:** Explicit glossary beats implicit reference — parallel agents won't re-read T1 consistently, but a 2–3 KB glossary file fits every prompt. Makes tone decisions auditable and fixable in one place.

**Альтернатива:** Pass T1 file paths as reference — rejected: bloats each agent prompt, agents may interpret differently. No glossary — rejected per user choice; drift risk too high.

### DD-4: Task granularity follows skill family boundaries

**Решение:** Each non-anchor task translates one skill family (SKILL.md + its agents + references + examples) as a unit. Exceptions: gp+gst are bundled (both small git skills), `/hi` + local `.claude/skills/*` are bundled (all have no agents/refs), docs+README+CLAUDE.md are one task, JSON metadata is one tiny task.

**Обоснование:** A skill family is internally consistent — SKILL.md prompts reference their agents' output schemas, references define formats the agents produce. Translating a family as a unit keeps that internal contract coherent during review. File-count per task stays under 20 and under ~1,000 lines; fits a single subagent's context.

**Альтернатива:** Per-file tasks (~70 tasks) — rejected: dispatch overhead, loss of family consistency. One-big-task — rejected: context overflow.

### DD-5: R5 language-rule replacement text

**Решение:** In `skills/fix/SKILL.md`, `skills/review/SKILL.md`, `skills/explore/SKILL.md`, `skills/bootstrap/SKILL.md`, replace `Язык контента — русский` with exactly:

```
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
```

**Обоснование:** User-specified in task Synthesize. Uniform phrasing across all four sites so downstream readers see the rule consistently. Mention both CLAUDE.md and AGENTS.md since different projects use different conventions.

**Альтернатива:** Per-skill custom phrasing — rejected: invites drift and contradicts the "single source of truth" spirit.

### DD-6: No worktree isolation for parallel tasks

**Решение:** Dispatch parallel sub-agents without `isolation: worktree`. All tasks operate on the same working tree.

**Обоснование:** Explorer confirms zero file intersection between Tasks 3–13. Each task's file set is under a distinct top-level path (`skills/do/**`, `skills/fix/**`, etc.) or fully disjoint (`docs/`, root files, JSON). Worktree overhead isn't justified.

**Альтернатива:** Worktree per agent — rejected: merge overhead with no conflict surface.

### DD-7: Frontmatter `name` preservation, `description` translation

**Решение:** In every SKILL.md and agent `.md`, preserve the `name:` identifier byte-for-byte. Translate only the `description:` string to a natural-English imperative trigger sentence matching the existing Russian register (e.g., `skills/gca/SKILL.md` description translates to "Git staging and commit with smart file grouping and SP workflow awareness. Triggered when…").

**Обоснование:** Plugin runtime binds skills/agents by `name`. Changing `name` breaks all cross-references in SKILL.md prompts that call agents by filename (e.g., `agents/task-explorer.md`). `description` is the semantic activation hint — must be English for English users.

**Альтернатива:** Rename for English slug aesthetics — rejected: breaks the plugin.

## Tasks

### Task 1: Translate task+plan nucleus (anchor)

- **Files:** `skills/task/SKILL.md`, `skills/task/agents/task-explorer.md`, `skills/task/agents/task-architect.md`, `skills/task/reference/synthesize-guide.md`, `skills/task/reference/frontend-guide.md`, `skills/task/reference/elements-of-style-rules.md`, `skills/task/examples/simple-task.md`, `skills/task/examples/complex-task.md`, `skills/plan/SKILL.md`, `skills/plan/agents/plan-explorer.md`, `skills/plan/agents/plan-designer.md`, `skills/plan/agents/plan-reviewer.md`, `skills/plan/reference/plan-format.md`, `skills/plan/reference/routing-rules.md`, `skills/plan/reference/elements-of-style-rules.md`, `skills/plan/examples/simple-plan.md`, `skills/plan/examples/complex-plan.md` (all edit)
- **Depends on:** none
- **Scope:** L
- **What:** Translate all Russian prose in the task+plan skill family to English. Rename `**Сложность:**` → `**Complexity:**` in task template and examples; update `skills/plan/SKILL.md:41` to extract from `«Complexity»`. Rename `**Решение:**/**Обоснование:**/**Альтернатива:**` → `**Decision:**/**Rationale:**/**Alternative:**` in plan-format.md, plan examples, and plan-designer agent output schema. Translate all frontmatter `description` fields. Translate section headers (`## Фаза N` → `## Phase N`, etc.) and embedded strings (notify titles, commit message templates).
- **How:** Read `skills/gca/reference/commit-convention.md` for English register. Preserve YAML frontmatter structure and `name` values. Keep code blocks' identifiers and structured-output field names (`TICKET_ID`, `TASK_SLUG`, etc.) unchanged. Rewrite prose in imperative active voice matching existing English segments in plan-designer.md and commit-convention.md. Apply R2/R3 renames before translating surrounding prose so grep can verify coupling completeness.
- **Context:** Full contents of all 17 files; `skills/gca/reference/commit-convention.md` (already-English tone reference); task file `docs/ai/53-translate-to-english/53-translate-to-english-task.md` Constraints section.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/task/ skills/plan/ --include='*.md' -l` → empty. `grep -rn 'Сложность\|Решение:\|Обоснование:\|Альтернатива:' skills/task/ skills/plan/` → empty. `head -1 skills/task/SKILL.md skills/plan/SKILL.md` → both `---`.

### Task 2: Generate translation glossary

- **Files:** `docs/ai/53-translate-to-english/glossary.md` (create)
- **Depends on:** Task 1
- **Scope:** S
- **What:** Extract canonical translations from Task 1 output. Produce a glossary with three sections: (1) recurring section headers (Russian → English), (2) recurring imperative phrases and tone examples, (3) the exact R5 replacement text for the language rule.
- **How:** Read the 17 translated files from Task 1. Diff against untranslated reference (or original git blob) only if needed — the translated files alone are sufficient. List every `##` / `###` header pair seen, every frontmatter description pattern, every recurring imperative phrase. Keep the file under 200 lines so it fits every subsequent agent prompt.
- **Context:** All 17 files from Task 1 (post-translation); original Russian files from `git show HEAD~:<path>` if needed for mapping.
- **Verify:** `test -f docs/ai/53-translate-to-english/glossary.md && wc -l docs/ai/53-translate-to-english/glossary.md` → file exists, under 250 lines. Manual spot check: the file contains entries for `Фаза→Phase`, `Вход→Input`, `Правила→Rules`, `Материалы→Materials`, `Решай, не спрашивай→Decide, don't ask`, and the R5 replacement string verbatim.

### Task 3: Translate /do skill family

- **Files:** `skills/do/SKILL.md`, `skills/do/agents/*.md` (8 files: task-executor, spec-reviewer, quality-reviewer, validator, code-polisher, formatter, doc-updater, report-writer), `skills/do/reference/status-protocol.md`, `skills/do/reference/report-format.md` (all edit)
- **Depends on:** Task 2
- **Scope:** L
- **What:** Translate all Russian prose. Translate frontmatter `description` fields. Translate embedded strings (notify titles, commit message templates, status-protocol labels).
- **How:** Read the glossary. Apply section-header and recurring-phrase translations verbatim from it. Preserve frontmatter `name` values. Keep code block identifiers and structured-output field names (status protocol keys like `STATUS`, `ACTION`, etc.) unchanged.
- **Context:** Glossary file; all files in `skills/do/`; tone reference `skills/task/SKILL.md` (post-T1).
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/do/ --include='*.md' -l` → empty.

### Task 4: Translate /fix skill family

- **Files:** `skills/fix/SKILL.md`, `skills/fix/agents/*.md` (3 files: fix-context-collector, fix-investigator, fix-log-writer), `skills/fix/reference/fix-log-format.md` (all edit)
- **Depends on:** Task 2
- **Scope:** M
- **What:** Translate prose, frontmatter descriptions, embedded strings, section headers. Replace the `Язык контента — русский` rule in `skills/fix/SKILL.md` with the DD-5 text.
- **How:** Apply glossary. Locate the language rule in the SKILL.md Rules section and replace with the DD-5 block exactly.
- **Context:** Glossary; all files in `skills/fix/`; DD-5 from this plan.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/fix/ --include='*.md' -l` → empty. `grep -l 'Язык контента' skills/fix/ -r` → empty. `grep -F 'Language: match the ticket/input language' skills/fix/SKILL.md` → one hit.

### Task 5: Translate /review skill family

- **Files:** `skills/review/SKILL.md`, `skills/review/agents/*.md` (4 files: review-analyzer and 3 others), `skills/review/reference/*.md` (all edit)
- **Depends on:** Task 2
- **Scope:** M
- **What:** Translate prose, frontmatter, embedded strings, headers. Replace R5 rule with DD-5 text in `skills/review/SKILL.md`.
- **How:** Apply glossary. Same R5 replacement pattern as Task 4.
- **Context:** Glossary; all files in `skills/review/`; DD-5.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/review/ --include='*.md' -l` → empty. `grep -l 'Язык контента' skills/review/ -r` → empty.

### Task 6: Translate /explore skill family

- **Files:** `skills/explore/SKILL.md`, `skills/explore/agents/explore-agent.md`, `skills/explore/agents/explore-log-writer.md`, `skills/explore/reference/exploration-log-format.md` (all edit)
- **Depends on:** Task 2
- **Scope:** S
- **What:** Translate prose, frontmatter, embedded strings, headers. Replace R5 rule with DD-5 text in `skills/explore/SKILL.md`.
- **How:** Apply glossary. Same R5 replacement pattern.
- **Context:** Glossary; all files in `skills/explore/`; DD-5.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/explore/ --include='*.md' -l` → empty. `grep -l 'Язык контента' skills/explore/ -r` → empty.

### Task 7: Translate /bootstrap skill family

- **Files:** `skills/bootstrap/SKILL.md`, `skills/bootstrap/agents/*.md` (10 files), `skills/bootstrap/reference/*.md` (5 files) (all edit)
- **Depends on:** Task 2
- **Scope:** L
- **What:** Translate prose, frontmatter, embedded strings, headers across SKILL + 10 agents + 5 references. Replace R5 rule with DD-5 text in `skills/bootstrap/SKILL.md`.
- **How:** Apply glossary. Largest agent count of any family — translate in order SKILL → references → agents so agent prompts can reference finalized reference wording.
- **Context:** Glossary; all files in `skills/bootstrap/`; DD-5.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/bootstrap/ --include='*.md' -l` → empty. `grep -l 'Язык контента' skills/bootstrap/ -r` → empty.

### Task 8: Translate /gca skill family

- **Files:** `skills/gca/SKILL.md`, `skills/gca/reference/commit-convention.md`, `skills/gca/reference/staging-strategy.md` (all edit)
- **Depends on:** Task 2
- **Scope:** S
- **What:** Translate remaining Russian prose. Note: `commit-convention.md` is already mostly English (the commit-format rules) — only section headers and surrounding prose need translation.
- **How:** Apply glossary. Preserve all concrete commit-format examples byte-identically (e.g., `TICKET type(scope): subject`).
- **Context:** Glossary; all files in `skills/gca/`.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/gca/ --include='*.md' -l` → empty. `grep -F 'TICKET type(scope):' skills/gca/reference/commit-convention.md` → present.

### Task 9: Translate /gp and /gst skill families

- **Files:** `skills/gp/SKILL.md`, `skills/gp/agents/git-pre-checker.md`, `skills/gp/agents/git-pusher.md`, `skills/gst/SKILL.md`, `skills/gst/agents/git-data-collector.md` (all edit)
- **Depends on:** Task 2
- **Scope:** M
- **What:** Translate prose, frontmatter, embedded strings, headers across both git-focused families.
- **How:** Apply glossary. Preserve all git command strings and structured-output field names (`BRANCH`, `PUSH_STATUS`, etc.).
- **Context:** Glossary; all files in `skills/gp/` and `skills/gst/`.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/gp/ skills/gst/ --include='*.md' -l` → empty.

### Task 10: Translate /pr skill family

- **Files:** `skills/pr/SKILL.md`, `skills/pr/agents/pr-data-collector.md`, `skills/pr/agents/pr-body-generator.md`, `skills/pr/reference/pr-body-format.md` (all edit)
- **Depends on:** Task 2
- **Scope:** M
- **What:** Translate prose, frontmatter, embedded strings, headers.
- **How:** Apply glossary. Preserve GitHub PR body templates and `gh` command strings.
- **Context:** Glossary; all files in `skills/pr/`.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/pr/ --include='*.md' -l` → empty.

### Task 11: Translate /hi and local skills

- **Files:** `skills/hi/SKILL.md`, `.claude/skills/sp-create/SKILL.md`, `.claude/skills/sp-release/SKILL.md` (all edit)
- **Depends on:** Task 2
- **Scope:** L
- **What:** Translate prose, frontmatter, embedded strings, headers for the welcome skill and the two local development skills. These are the longest individual SKILL.md files (442 + 403 lines).
- **How:** Apply glossary. `/hi` description is user-facing — match the welcoming register. Local skills are for plugin development — keep technical imperative register.
- **Context:** Glossary; the three files.
- **Verify:** `grep -rP '[А-Яа-яЁё]' skills/hi/ .claude/skills/ --include='*.md' -l` → empty.

### Task 12: Translate README, CLAUDE.md, and docs/

- **Files:** `README.md`, `CLAUDE.md`, `docs/*.md` (14 files: notify, do, gp, gca, task, plan, pr, fix, review, gst, explore, hi, bootstrap, plus any others present) (all edit)
- **Depends on:** Task 2
- **Scope:** L
- **What:** Translate all Russian prose in the user-facing entry points and skill documentation. Update the "Implemented skills" section in README/CLAUDE.md with English descriptions. Update the CLAUDE.md `Язык контента` convention note to match the DD-5 rule (apply to the docs note as well, worded for the README context).
- **How:** Apply glossary. Keep all code blocks and paths unchanged. Keep skill command names (`/task`, `/plan`, etc.) unchanged.
- **Context:** Glossary; all files in scope; task file Constraints.
- **Verify:** `grep -rP '[А-Яа-яЁё]' README.md CLAUDE.md docs/ --include='*.md' -l` → empty.

### Task 13: Translate JSON metadata descriptions

- **Files:** `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `package.json` (edit)
- **Depends on:** Task 2
- **Scope:** S
- **What:** Translate the `description` string values in all three JSON files.
- **How:** Preserve JSON structure, keys, and all other values byte-identical. Modify only `description` fields. Validate JSON syntax after edit.
- **Context:** Glossary; the three files.
- **Verify:** `python3 -c "import json; [json.load(open(p)) for p in ['.claude-plugin/plugin.json','.claude-plugin/marketplace.json','package.json']]; print('OK')"` → `OK`. `grep -P '[А-Яа-яЁё]' .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json` → empty.

### Task 14: Validation

- **Files:** —
- **Depends on:** Tasks 1–13
- **Scope:** S
- **What:** Run the global validation suite. Fix any Russian remnants found inline.
- **How:**
  ```bash
  grep -rP '[А-Яа-яЁё]' skills/ .claude/skills/ docs/ README.md CLAUDE.md .claude-plugin/ package.json --include='*.md' --include='*.json' -l
  head -1 skills/*/SKILL.md .claude/skills/*/SKILL.md commands/*.md 2>/dev/null
  python3 -c "import json; [json.load(open(p)) for p in ['.claude-plugin/plugin.json','.claude-plugin/marketplace.json','package.json']]; print('OK')"
  pnpm run format:check
  grep -rn 'Сложность\|Решение:\|Обоснование:\|Альтернатива:\|Язык контента — русский' skills/ .claude/skills/ docs/ README.md CLAUDE.md 2>/dev/null
  ```
  First command: empty. Second: all lines `---`. Third: `OK`. Fourth: exits 0. Fifth: empty.
  If any remaining Russian or legacy-label hits found — fix in place, then re-run. Smoke-test one skill: `claude --plugin-dir .` and invoke `/hi` manually to confirm English activation and response.
- **Context:** All modified files from Tasks 1–13.
- **Verify:** All five commands above return the expected results. Manual `/hi` smoke test produces English output.

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** 14 tasks with disjoint file paths after the nucleus; Task 1 anchors tone, Task 2 produces the glossary, Tasks 3–13 parallelize over independent skill families and docs, Task 14 runs the global validation barrier.
- **Order:**
  Group 1 (sequential): Task 1 → Task 2
  ─── barrier ───
  Group 2 (parallel): Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10, Task 11, Task 12, Task 13
  ─── barrier ───
  Group 3 (sequential): Task 14

## Verification

- `pnpm run format:check` → exits 0 (no formatting regressions).
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); json.load(open('package.json')); print('OK')"` → prints `OK`.
- `grep -rP '[А-Яа-яЁё]' skills/ .claude/skills/ docs/ README.md CLAUDE.md .claude-plugin/ package.json --include='*.md' --include='*.json' -l` → returns nothing (no Russian Cyrillic remaining in scoped files).
- `head -1 skills/*/SKILL.md .claude/skills/*/SKILL.md commands/*.md` → every line is `---` (frontmatter structure preserved).
- `grep -l 'Сложность' skills/ -r` → empty (field-label rename complete).
- `grep -l 'Язык контента — русский' skills/ -r` → empty (language rule updated in all 4 skills).
- Manual smoke: `claude --plugin-dir .` then invoke `/hi` — skill activates on English trigger and responds in English.
- Manual smoke: run `/task` with a sample ticket → produces task file with `**Complexity:**` label.
- Manual smoke: feed the task file to `/plan` → plan-skill extracts `TASK_COMPLEXITY` without error and produces plan with `**Decision:**` / `**Rationale:**` / `**Alternative:**` labels.
- Manual smoke: all other skills (`/do`, `/gca`, `/gp`, `/pr`, `/gst`, `/fix`, `/explore`, `/review`, `/bootstrap`) activate on English trigger phrases and produce English output.
- Edge case: task file generated before this change (Russian labels in `docs/ai/`) is out of scope — regeneration not required per constraint.

## Materials

- [GitHub issue #53](https://github.com/projectory-com/sp/issues/53)
- `skills/task/SKILL.md` — upstream source of task template (field labels)
- `skills/plan/SKILL.md:41` — downstream consumer of `Complexity` field
- `skills/plan/reference/plan-format.md:19-24` — plan output contract
- `skills/gca/reference/commit-convention.md:15` — English-commit mandate (already in place)
- `skills/fix/SKILL.md`, `skills/review/SKILL.md`, `skills/explore/SKILL.md`, `skills/bootstrap/SKILL.md` — `Язык контента` rule sites
- `skills/task/examples/simple-task.md`, `skills/task/examples/complex-task.md` — task artifact examples
- `skills/plan/examples/simple-plan.md`, `skills/plan/examples/complex-plan.md` — plan artifact examples
- `CLAUDE.md` — project conventions (update language note)
- `README.md` — user-facing entry point
