---
name: yoke-validate
description: >-
  Validates SKILL.md files changed in the current branch against
  elements-of-style (Strunk) for prose and plugin-dev's skill-development
  conventions for structure, applies safe fixes automatically, and reports the
  rest. Activates when the user writes "validate", "validate skill", "validate
  skills", "validate changed skills", "lint skills", "валидайт", "валидайт
  скилы", "прогони валидацию", "проверь скилы".
---

# Validate

Run two lenses on every `SKILL.md` changed in this branch and auto-fix the safe findings.

## Lenses

Both lens skills must be installed locally:

- **`elements-of-style:writing-clearly-and-concisely`** — invoke via the Skill tool, then Read its `elements-of-style.md` reference. Drives prose tightening.
- **`plugin-dev:skill-development`** — invoke via the Skill tool (or Read the cached `SKILL.md` directly if the loader misbehaves). Drives structural validation.

If either lens is not installed, stop and name the missing dependency. Do not inline the lens's rules.

## Scope

Process only `*/SKILL.md` paths returned by:

```bash
git diff --name-only main...HEAD | grep -E '/SKILL\.md$' | sort -u
```

If the result is empty (the current branch is `main`, or no `SKILL.md` differs from `main`), report "nothing to validate" and stop. Skip commands, agents, references, `CLAUDE.md`, and `docs/`.

## Process per file

For each path:

1. **Read** the file.
2. **Apply elements-of-style.** For each Strunk violation, apply the fix via Edit when safe:
   - Drop needless words (Rule 13): `that is`, `in order to` → `to`, `actually`, `really`, weakening `very`.
   - Active voice (Rule 10): rewrite passive when the actor is clear.
   - Positive form (Rule 11): convert `not X` to a positive antonym where natural.
   - Concrete language (Rule 12): replace vague quantifiers (`a lot of` → `substantial`, `several types of` → `several`).
   - Record judgement-call rewrites that risk changing meaning as unresolved findings instead of applying them.
3. **Apply plugin-dev's skill-development checklist.**
   - Frontmatter contains `name` and `description`. Missing fields → add (derive `description` from the body when obvious; otherwise record as unresolved).
   - `description` uses third person and lists concrete trigger phrases.
   - Body uses imperative/infinitive form throughout. Convert every `you`, `your`, `you'll`, `you're` to imperative via Edit. Apply across the whole body, not only the diff hunks against `main`.
   - Body word count ≤ 2000 (target) / ≤ 5000 (hard ceiling). Over the ceiling → record "split into `references/`" as unresolved.
   - Every referenced file (`${CLAUDE_PLUGIN_ROOT}/...`, `references/...`, etc.) resolves on disk. Broken references → record as unresolved.
4. **Track** every applied fix and every unresolved finding for this file.

## Report

After processing every file, print one combined report:

- Files processed — count and paths.
- Auto-applied fixes per file — one-line summary each.
- Unresolved findings per file — judgement calls and structural issues that need human input.
- Files with no findings → list as `OK`.

## Rules

- Process only `*/SKILL.md`. Skip commands, agents, references, docs, and `CLAUDE.md`.
- Auto-fix safe and mechanical findings; defer judgement calls to the report.
- Apply second-person → imperative across the whole body of every changed file, not only the diff hunks. The repo accepts the resulting rewrite cost in exchange for strict plugin-dev conformance.
- Never `git add`, `git commit`, or otherwise mutate git state. Leave the working tree dirty; the user commits through `/yoke:gca`.
- If `elements-of-style:writing-clearly-and-concisely` or `plugin-dev:skill-development` is missing, stop and report the missing dependency by name.
- Language: report in the conversation language; edits to `SKILL.md` stay in the file's original language (English, per yoke convention).
