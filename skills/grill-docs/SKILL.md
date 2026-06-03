---
name: grill-docs
description: >-
  Docs-aware grilling: interrogates the user's plan one question at a time AND
  maintains the domain glossary (.yoke/context.md) and architecture decision
  records (.yoke/adr/) inline as decisions crystallise. Used to stress-test a
  plan against the project's language and documented decisions; for a plain
  interview that writes no files, use grill. Activates when the user writes
  "grill-docs", "grill with docs", "grill and update the glossary", "grill and
  write ADRs", "stress-test against the glossary", "challenge my plan and
  capture decisions".
---

# Grill with docs

<what-to-do>

Interview the user relentlessly about every aspect of this plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

Ask **one question at a time through the AskUserQuestion tool**, waiting for the answer before continuing. Use a short `header` (≤12 chars) per question, and present 2–4 options with your **recommended answer first, labelled `(Recommended)`** and a one-line rationale; the user can pick "Other" to answer free-form. A later question usually depends on an earlier answer — resolve the branch in order, don't batch unrelated questions.

If a question can be answered by exploring the codebase, explore the codebase instead.

`$ARGUMENTS` — the plan, design, or topic to grill. If empty, ask via AskUserQuestion what they want to be grilled on.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

A single glossary and a single ADR directory for the whole repo, under `.yoke/`:

```
/
├── .yoke/
│   ├── context.md
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

Create files lazily — only when you have something to write. If no `.yoke/context.md` exists, create it when the first term is resolved. If no `.yoke/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `.yoke/context.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update the glossary inline

When a term is resolved, update `.yoke/context.md` right there. Don't batch these up — capture them as they happen. Use the format in [reference/CONTEXT-FORMAT.md](reference/CONTEXT-FORMAT.md).

`.yoke/context.md` should be devoid of implementation details. Do not treat `.yoke/context.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [reference/ADR-FORMAT.md](reference/ADR-FORMAT.md).

</supporting-info>

## Rules

- One AskUserQuestion per question. Wait for the answer before moving on.
- Every question offers a recommended answer, listed first; the user may answer free-form via "Other".
- Capture terminology in `.yoke/context.md` and decisions in ADRs inline, lazily — create files only when there is something to write.
- End the session by summarising the resolved decisions and confirming what was written to `.yoke/context.md` and `.yoke/adr/`.
- For a plain interview without documentation maintenance, use `/yoke:grill`.
- Language: match the user's language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
