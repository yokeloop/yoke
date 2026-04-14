# Plan Format

The output file format for `<slug>-plan.md` in Phase 6 (Write).

---

## Template

```markdown
# <Task title> — implementation plan

**Task:** <path to task file>
**Complexity:** <trivial | simple | medium | complex>
**Mode:** <inline | sub-agents | agent-team>
**Parallel:** <true | false>

## Design decisions

### DD-1: <What you're deciding>

**Decision:** <chosen option>
**Rationale:** <why, with a code reference>
**Alternative:** <rejected option — why not>

### DD-2: ...

## Tasks

### Task 1: <title>

- **Files:** `src/path/file.ts` (create), `src/path/other.ts:45-60` (edit)
- **Depends on:** none
- **Scope:** S
- **What:** <1–2 sentences — what exactly to do>
- **How:** <key implementation steps — concrete, not "add validation">
- **Context:** <files and lines for the agent to read>
- **Verify:** `npm test src/path/__tests__/file.test.ts` — green

### Task 2: <title>

- **Files:** `src/path/feature.ts` (create)
- **Depends on:** Task 1
- **Scope:** M
- **What:** <what to do>
- **Context:** <context>
- **Verify:** <check>

### Task N: Validation

- **Files:** —
- **Depends on:** all
- **Scope:** S
- **What:** Run full validation: lint, types, tests, build
- **Context:** —
- **Verify:** `npm run lint && npm run type-check && npm test && npm run build` — all green

## Execution

- **Mode:** <inline | sub-agents | agent-team>
- **Parallel:** <true | false>
- **Reasoning:** <one sentence — why this mode>
- **Order:**
  Group 1 (parallel): Task 1, Task 2
  ─── barrier ───
  Group 2 (sequential): Task 3 → Task 4
  ─── barrier ───
  Group 3 (parallel): Task 5, Task 6

Order format: parallel groups dispatch simultaneously, sequential — in sequence.
Barrier = the next group starts after every task in the current one finishes.
All tasks sequential — write as `Task 1 → Task 2 → Task 3`.

## Verification

<Criteria from the task file — unchanged>

## Materials

<From the task file — unchanged>
```

---

## Format rules

- **The last task is always Validation.** Run the full test suite, lint, type-check.
- **Every task contains Verify.** A concrete command or observable behavior.
- **Context in a task — minimally sufficient.** Only files for _this_ task.
  Concrete paths and lines, no "read the whole project" or "see the plan file".
- **Design decisions are numbered** (DD-1, DD-2…) for referencing.
- **Mode and Parallel** — required header fields.
  `/sp:do` reads them directly.
