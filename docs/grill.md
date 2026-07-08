# Skill /grill

Interrogates you about a plan or design, one interactive question at a time, until you and the agent share the same understanding. Walks down each branch of the decision tree, resolving dependencies one by one. Read-only — produces no artifact; the value is the sharpened plan.

## Input

`$ARGUMENTS` — the plan, design, or topic to grill. If empty, asks via AskUserQuestion what to grill.

```
/yoke:grill should we cache sessions in Redis or Postgres
/yoke:grill review my plan for the new billing flow
```

## How it works

The skill poses each question through AskUserQuestion:

- a short header naming the decision;
- 2–4 answer options, the **recommended one first** (`(Recommended)`) with a one-line rationale;
- "Other" is always available for a free-form answer.

One question at a time. The agent waits for your answer, folds it in, then asks the next question down that branch. The agent surfaces contradictions immediately. When the tree is resolved, it summarises the decisions.

If a question is answerable from the codebase, the agent explores instead of asking.

## Output

No file. A shared understanding of the plan, plus a closing summary of resolved decisions.

For a version that also records terminology in `.yoke/context.md` and decisions as ADRs, use `/yoke:grill-docs`.

## Connections

Discovery front-end. Run before `/yoke:prd` or `/yoke:task` to harden an idea before formalising it.
