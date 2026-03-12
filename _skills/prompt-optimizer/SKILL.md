---
name: prompt-optimizer
description: 'Optimize a prompt stored in a file. Reads the file, improves the prompt, writes the result back. Triggers on: /prompt-optimizer, optimize prompt file, improve prompt in file. Requires a file path argument.'
---

# Prompt Optimizer (File-based)

Read a prompt from a file, analyze and improve it, then write the optimized version back to the same file.

## Invocation

```
/prompt-optimizer <path-to-file>
```

The argument is a path to a file containing the prompt to optimize. The path can be absolute or relative to the working directory.

## Process

### Step 1. Read the source file

Use the Read tool to load the file contents. If the file doesn't exist or is empty, inform the user and stop.

### Step 2. Classify complexity

Determine task type and calibrate effort:

| Complexity  | Analysis depth            | Example                             |
| ----------- | ------------------------- | ----------------------------------- |
| **Trivial** | Intent clarity is enough  | Typo fix, rename, one-liner         |
| **Simple**  | Intent + scope            | Single-function change, add a field |
| **Medium**  | All 5 dimensions          | New endpoint, refactor a module     |
| **Complex** | All 5 + suggest sub-tasks | New subsystem, architectural change |

For development prompts, also identify the type:

| Type          | Key requirements                                       |
| ------------- | ------------------------------------------------------ |
| Bug fix       | Error messages, repro steps, expected vs actual        |
| Feature       | Spec, acceptance criteria, integration points          |
| Refactor      | Current structure, target structure, "tests must pass" |
| Config/DevOps | Environment details, current config, desired state     |
| Exploration   | Constraints, goals, tradeoffs that matter              |

### Step 3. Analyze across 5 dimensions

Evaluate the prompt in priority order. Not every prompt needs all 5 — match depth to complexity.

**1. Intent Clarity** (highest impact)

- Could two people read this and produce the same output?
- Red flags: ambiguous verbs ("handle", "manage", "fix", "improve"), missing success criteria, implicit assumptions
- Fix: replace vague verbs with specific actions, state expected observable behavior

**2. Scope Boundaries**

- Red flags: multiple unrelated changes, "and also..." patterns, no mention of what should NOT change
- Fix: split compound prompts into atomic tasks, add explicit constraints

**3. Context Anchoring**

- Red flags: no file paths or function names, no reference to existing patterns, assumes prior conversation context
- Fix: reference specific files and functions, name existing patterns to follow

**4. Specificity**

- Red flags: "good", "interesting", "properly", "fast", "clean"
- Fix: replace with concrete criteria ("response time < 200ms", "article with concrete examples and data")

**5. Acceptance Criteria**

- Red flags: no testable assertions, "it should work", no edge cases
- Fix: add concrete checks ("npm test should pass", "return 404 when userId doesn't exist")

### Step 4. Rewrite the prompt

**For development prompts**, use this structure (adapt sections as needed — omit what's unnecessary):

```
## Task
[One clear sentence]

## Context
[Files, functions, architecture, tech stack]

## Requirements
[Specific, testable — each independently verifiable]

## Constraints
[What NOT to change, approaches to avoid]

## Verification
[How to confirm correctness]
```

**For general prompts**, apply these rules:

- Fix errors — spelling, grammar, punctuation in the original language
- Clarify intent — make implicit goals explicit
- Add missing context — audience, format, constraints (only genuinely missing)
- Structure — headers/lists for complex prompts, prose for simple ones
- Cut fluff — omit needless words, active voice over passive
- Advanced techniques ONLY when warranted: chain-of-thought, few-shot examples, role assignment

**Proportionality:**

- 1-2 sentence prompt -> 1-3 sentences
- Paragraph prompt -> structured paragraph
- Multi-part prompt -> headers/sections

### Step 5. Write the result back to the file

Use the Write tool to overwrite the source file with the improved prompt. Do NOT add any meta-commentary, changelog, or "what changed" section into the file — only the clean optimized prompt.

### Step 6. Report to user

After writing, briefly tell the user:

1. What key improvements were made (2-3 sentences max)
2. If the prompt was split into multiple tasks, note that the file contains the first/main task and list the others

## Rules

**DO:**

- Preserve the original language (Russian stays Russian, English stays English)
- Preserve the original intent — improve formulation, not change the task
- Keep the same scope — don't add tasks the author didn't request
- Match output complexity to input complexity
- Read the file BEFORE writing to it

**DO NOT:**

- Add "You are an expert..." to every prompt — only when domain expertise matters
- Wrap the prompt in code fences or quotes in the output file
- Add boilerplate context that doesn't serve the specific task
- Change the task itself — only improve how it's communicated
- Add meta-information ("This prompt was optimized by...") to the file
- Over-engineer simple prompts with unnecessary structure

## Anti-patterns to fix

| Anti-pattern           | Problem                                     | Fix                                           |
| ---------------------- | ------------------------------------------- | --------------------------------------------- |
| Kitchen sink           | Multiple unrelated tasks                    | Split into separate prompts (note in report)  |
| Phantom context        | "Fix the bug we discussed"                  | Flag to user — cannot resolve without context |
| Vague scope            | "Update the user module"                    | Specify files and functions                   |
| Missing negatives      | No constraints on what to preserve          | Add "do not change..." section                |
| Assumed knowledge      | References internal APIs without details    | Include type signatures or endpoints          |
| Premature optimization | "Make it fast" without data                 | Ask for measurable target                     |
| Over-specification     | Dictating exact implementation line by line | State the goal, let AI choose approach        |

## Edge cases

- **Prompt is already good**: Write it back unchanged. Tell the user it's already well-structured.
- **Intent completely unclear**: Do NOT guess. Ask the user clarifying questions instead of writing a rewritten file.
- **File contains non-prompt content** (code, config, etc.): Inform the user this doesn't appear to be a prompt file. Do not modify.
- **Multiple prompts in one file**: Optimize all of them, preserving any separators or structure.

## Important

- Always read the file first — never assume contents
- The file is overwritten in place — no backup is created
- Only the optimized prompt goes into the file, no commentary
- If the path argument is missing, ask the user for it — do not guess
