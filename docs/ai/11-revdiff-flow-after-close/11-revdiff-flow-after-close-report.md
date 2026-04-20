# Report: 11-revdiff-flow-after-close

**Plan:** docs/ai/11-revdiff-flow-after-close/11-revdiff-flow-after-close-plan.md
**Mode:** sub-agents
**Status:** ✅ complete

## Tasks

| #   | Task                                             | Status  | Commit    | Concerns   |
| --- | ------------------------------------------------ | ------- | --------- | ---------- |
| 1   | Rewrite `skills/task/SKILL.md` revdiff bullet    | ✅ DONE | `9d52739` | see below  |
| 2   | Rewrite `skills/plan/SKILL.md` revdiff bullet    | ✅ DONE | `d4eaa4e` | see below  |
| 3   | Rewrite `skills/do/SKILL.md` revdiff bullet      | ✅ DONE | `ce99939` | see below  |
| 4   | Validation barrier                               | ✅ DONE | —         | —          |

## Post-implementation

| Step          | Status   | Commit    |
| ------------- | -------- | --------- |
| Polish        | N/A      | —         |
| Validate      | ✅ pass  | —         |
| Documentation | N/A      | —         |
| Format        | ✅ done  | `19a9d21` |

Polish and Documentation are N/A: the change is markdown-only in skill instructions — nothing to simplify in code, and the plan constraints forbid edits to `docs/*.md` and `README.md`.

## Concerns

### Tasks 1, 2, 3 — verification-spec defect (non-blocking)

The plan's per-task Verify step specified `grep -cn "Return to the \"Offer 3 options\" step above."` should return 2 case-sensitive matches per file. The approved bullet text uses `Return` at sentence-start (step 3) and `return` mid-sentence (in the install-hint fallback: "then return to..."). Byte-for-byte implementation of the spec's code fence yields 1 case-sensitive + 1 case-insensitive match (2 matches total under case-insensitive grep). Task 4 used a case-insensitive grep to verify the 2 matches. The loop-back phrase text is present exactly twice in every file as the spec intended; the grep-case quibble is a spec-authoring slip, not an implementation defect.

### Task 3 — prettier re-indentation of fallback lines (resolved)

On post-edit prettier run, the "If the plugin is missing" and (in `/do`) "If the Skill return is empty" lines were re-indented from 2-space/5-space (sibling of numbered steps) to 5-space/7-space (continuation of the preceding list item). This changes the markdown AST nesting but not the text content: each line self-identifies its scope ("If the plugin is missing — print..." / "If the Skill return is empty, skip this entire step"), so the orchestrator reading the SKILL.md picks up the correct semantics regardless of nesting depth. Accepting prettier's authoritative formatting avoids fighting the pre-commit hook. Committed separately as `19a9d21`.

## Validation

```
python3 plugin.json/marketplace.json parse    ✅ OK
head -1 skills/{task,plan,do}/SKILL.md        ✅ each file starts with ---
grep "After revdiff closes, continue..."      ✅ 1 match per file
grep "Return to the \"Offer 3 options\"..."   ✅ 2 matches per file (case-insensitive)
grep "If the ... return is empty"             ✅ 1 match per file
grep "append review notes" (do only)          ✅ 1 match
grep "## Review notes" (do only)              ✅ 1 match
grep "skills/gp/agents/git-pre-checker.md:43-54" (do only)  ✅ 1 match
pnpm run format:check                         ✅ all matched files use Prettier code style
```

## Changes summary

| File                    | Action   | Description                                                                                                                           |
| ----------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `skills/task/SKILL.md`  | modified | Line 272 bullet restructured: 4-step inline sequence with continuation obligation before `/revdiff` call; empty-return skip; canonical loop-back phrase. |
| `skills/plan/SKILL.md`  | modified | Line 298 bullet restructured with the same 4-step template, plan-file args.                                                           |
| `skills/do/SKILL.md`    | modified | Line 290 bullet restructured with the 4-step skeleton; step 2 carries nested sub-list preserving PR #1 semantics (cascade, report append, gitignore check, auto-commit). |

## Commits

- `9d52739` `#11 fix(11-revdiff-flow-after-close): restructure task revdiff bullet to execute annotations after close`
- `d4eaa4e` `#11 fix(11-revdiff-flow-after-close): restructure plan revdiff bullet to execute annotations after close`
- `ce99939` `#11 fix(11-revdiff-flow-after-close): restructure do revdiff bullet to execute annotations after close`
- `19a9d21` `#11 style(11-revdiff-flow-after-close): apply prettier to revdiff bullets`
