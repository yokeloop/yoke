# Translate sp plugin content to English — review report

**Slug:** 53-translate-to-english
**Branch:** 53-translate-to-english
**Reviewer:** code-reviewer subagent
**Outcome:** 6 issues found, 5 fixed, 1 intentionally skipped

## Summary

The translation is structurally sound. No Cyrillic leaked into any in-scope file, all YAML `name:` identifiers are preserved, the R2/R3 field-label couplings (`Complexity` in task template + plan extractor; `Decision/Rationale/Alternative` in plan format + examples + plan-designer agent) are consistent end-to-end, and agent cross-references resolve. Parallel dispatch across 11 sub-agents did not introduce tone drift in section headers or the `You are the orchestrator.` opening.

The main regression was a **language-rule inconsistency**: `task/SKILL.md`, `plan/SKILL.md`, and `do/SKILL.md` retained shortened or legacy phrasings of the R5 rule while the other four skills received the canonical bullet. This was fixed.

## Findings

| # | Severity | Category | Location | Issue | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | Important | LanguageRule | `skills/task/SKILL.md:289`, `skills/plan/SKILL.md:305` | `Content language — ...` instead of canonical R5 bullet | Fixed `c3d66ca` |
| 2 | Important | LanguageRule | `skills/do/SKILL.md:303` | Shortened R5 variant missing CLAUDE.md/AGENTS.md fallback | Fixed `c3d66ca` |
| 3 | Critical | OutOfScope | `docs/ai/18-bootstrap/*.md` (4 files) | Russian artifacts — pre-existing, not a branch regression | Fixed `43281b3` (user opted to translate) |
| 4 | Important | ToneDrift | `skills/plan/agents/plan-designer.md:19` | `Decide, don't ask.` only in plan-designer, absent from sibling investigator/architect agents | Skipped — pre-existing structural gap; adding it changes semantics, not a translation fix |
| 5 | Minor | QualityOfEnglish | `skills/hi/SKILL.md:40` | ASCII arrow `->` instead of `→` | Fixed `c3d66ca` |
| 6 | Minor | QualityOfEnglish | `skills/hi/SKILL.md:77` | ASCII arrow `->` instead of `→` | Fixed `c3d66ca` |

## Verified clean

- No Cyrillic in `skills/`, `.claude/skills/`, `README.md`, `CLAUDE.md`, `docs/*.md`, `.claude-plugin/`, `package.json`.
- No lingering `Сложность`, `Решение:`, `Обоснование:`, `Альтернатива:` anywhere in `skills/`.
- `skills/plan/SKILL.md:41` extracts `TASK_COMPLEXITY` from `«Complexity»` correctly.
- All YAML `name:` identifiers preserved (task, plan, fix, review, explore, bootstrap, do, hi, gp, pr, gst, gca, sp-create, sp-release).
- Cross-references between SKILL.md files and their agents/references resolve.
- R5 rule now present verbatim in all 7 SKILL.md sites (fix, review, explore, bootstrap + task, plan, do).
- `pnpm run format:check` passes.
- JSON validation passes.

## Commits produced by this review

- `c3d66ca` — `#53 refactor(53-translate-to-english): unify language rule across skills and polish hi arrows`
- `43281b3` — `#53 docs(53-translate-to-english): translate 18-bootstrap artifacts to English`

## Known deferred items

- **ISSUE-4** (`Decide, don't ask.` gap): this is a structural tone-consistency question, not a translation defect. Adding it to task-explorer / task-architect / plan-explorer would change agent behavior semantics. Deferred as a separate follow-up if desired.
- **`docs/ai/**` other historical artifacts**: 19 other pre-existing task/plan/report files remain in Russian. They are ephemeral and out of scope per the task constraints; only `18-bootstrap/*` was explicitly chosen for translation during review fix selection.
- **Manual smoke test**: `claude --plugin-dir .` and interactive invocation of `/hi`, `/task`, `/plan`, `/do` on English triggers — deferred to reviewer. Programmatic verification (no Russian in description fields, frontmatter intact, couplings consistent) confirms expected behavior.

## Next steps

- `/sp:gp` — push to origin.
- `/sp:pr` — create or update the PR.
