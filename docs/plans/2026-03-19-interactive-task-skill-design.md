# Interactive /task skill with completion loop

## Problem

The `/task` skill writes clarifying questions as checkboxes in the task file. Users must manually edit the file to answer them. After writing the task file, the skill prints a copy-paste string for `/sp:plan` instead of offering an automatic transition.

## Decisions

### D1: Replace file-based questions with AskUserQuestion

Questions are asked interactively via AskUserQuestion in batches of 1-4. Answers are incorporated into Requirements/Constraints/Context directly. The "Уточняющие вопросы" section is removed from the task file format.

**Why:** File-based checkboxes break the flow. The user must leave Claude, edit a markdown file, and return. Interactive questions keep the user in the conversation.

### D2: Add completion loop (Phase 5)

After writing the task file, a cyclic menu via AskUserQuestion:

1. **Run /sp:plan** (recommended) — invokes Skill tool automatically
2. **Review via plannotator** — invokes `/plannotator-annotate`, applies edits, shows menu again
3. **Finish** — prints path and exits

**Why:** Copy-paste strings are friction. Automatic transitions and review loops let the user iterate without leaving the session.

### D3: Invoke tools via Skill tool

Both `/sp:plan` and `/plannotator-annotate` are invoked through the Skill tool, not CLI or copy-paste.

### D4: Clean up /plan

Remove TASK_QUESTIONS extraction, checkbox validation, and the "Нерешённые task-вопросы" line from the plan-designer prompt.

## Scope

### Changed files

1. `skills/task/SKILL.md` — Phase 3 (interactive questions), Phase 4 (remove questions section), new Phase 5 (completion loop)
2. `skills/task/reference/synthesize-guide.md` — remove checkbox format from questions section, add AskUserQuestion instruction
3. `skills/task/examples/simple-task.md` — remove "Уточняющие вопросы" section
4. `skills/task/examples/complex-task.md` — remove "Уточняющие вопросы" section
5. `skills/plan/SKILL.md` — remove TASK_QUESTIONS, checkbox check, plan-designer reference

### Not changed

- Phase 1 (Parse) and Phase 2 (Investigate) in /task — untouched
- /do and /review skills — no dependency on questions section
- Agent definitions in agents/ — untouched

## Design detail

### Phase 3 (Synthesize) — changes

After applying 5 dimensions:

1. Generate 3-7 questions per synthesize-guide rules
2. Ask via AskUserQuestion in batches of 1-4, recommended option first with "(Recommended)"
3. After each batch: revise Requirements/Constraints/Context based on answers
4. If user selects "Other" — incorporate free-text input
5. Transition criterion: all questions asked and answered

**Constraint:** AskUserQuestion works only from the main orchestrator, not from sub-agents. Phase 3 already runs at orchestrator level.

### Phase 4 (Write) — changes

- Remove "Уточняющие вопросы" section from task file template
- Remove step 5 (print copy-paste string)
- Answers are already embedded in the task text from Phase 3

### Phase 5 (Complete) — new

```
loop:
  Show path to task file
  AskUserQuestion with 3 options:
    1. "Запустить /sp:plan (Recommended)" → Skill(/sp:plan, args=path) → exit
    2. "Ревью через plannotator" → Skill(/plannotator-annotate, args=path) → apply edits → loop
    3. "Завершить" → print path → exit
```

After plannotator: read annotations, rework task file, rewrite, show menu again.

### /plan cleanup

- Phase 1 step 2: remove TASK_QUESTIONS from extraction list
- Phase 1 step 4: remove "Уточняющие вопросы" check and warning
- Phase 3 (Design): remove "Нерешённые task-вопросы: [вставить TASK_QUESTIONS]" from plan-designer prompt
