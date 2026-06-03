# S1 — `.yoke/` artifact convention + path migration

**Slug:** 18-yoke-artifact-convention
**Ticket:** https://github.com/yokeloop/yoke/issues/18
**Complexity:** complex
**Type:** general

## Task

Move every yoke artifact path to the single `.yoke/` root — `.yoke/context.md`, `.yoke/adr/`, `.yoke/ai/<slug>/`, `.yoke/journal.md` — across all skills, the `/pr` script, README, and CLAUDE.md, and delete the `.gitignore`-probing logic that picked the location.

## Context

### Area architecture

This is the yoke plugin repo. Skills are markdown files under `skills/<name>/SKILL.md` (plus `agents/` and `reference/` subdirs). Each skill currently **hard-codes** its artifact paths as literal strings — there is no shared variable or config. The three legacy locations are:

- `docs/ai/<slug>/` — per-task pipeline artifacts (PRD, task, plan, report, exploration, issues index)
- root `CONTEXT.md` (+ `CONTEXT-MAP.md`) — the domain glossary
- `docs/adr/` — architecture decision records

ADR 0004 (`docs/adr/0004-yoke-artifact-root.md`) is the source of truth for the new convention and is itself one of the files that moves. The migration is the spine the rest of the 2.0 epic (#17) depends on; this slice blocks S3/S4/S5. `do`, `journal`, and `bootstrap` adopt the convention in their own slices and are **out of scope here**.

Skills hand off paths to each other as literal strings (task→plan→do→review, prd→issues, gca stages whatever the pipeline emits), so the prefix must change everywhere at once or a half-migrated pipeline passes a `.yoke/...` path to a skill still expecting `docs/ai/...`.

### Files to change

**Skills writing/reading `docs/ai/` (all migrate to `.yoke/ai/<slug>/`):**

In-scope-by-ticket:

- `skills/prd/SKILL.md:5,17,23,25,28` — description, domain-doc read, `mkdir -p` + save path, idempotency check, `gh issue create --body-file`
- `skills/issues/SKILL.md:6,23,69` — description, domain-doc read, save index path; `skills/issues/reference/github-issues.md:10,14`
- `skills/review/SKILL.md:29,53,54,56,63,64,146,160-167` — task-file discovery, report/fixes/review paths, **gitignore probe + commit block (line 160)**; `skills/review/agents/code-reviewer.md:36`
- `skills/gca/SKILL.md:26,47,69` — `$ARGUMENTS` path hint, artifact staging, staging table row `docs/ai/**`; `skills/gca/reference/commit-convention.md:99`; `skills/gca/reference/staging-strategy.md:20`
- `skills/grill-docs/SKILL.md:6,39,40-41,51-53,56-60,63,69,83,85,87,105-106` — glossary + ADR paths and file-structure trees; reference files below
- `skills/grill/SKILL.md:8,51` — prose pointers to grill-docs glossary name
- `skills/handoff/SKILL.md` — writes to OS temp, **no path strings to change**; add one note that referenced artifacts now live under `.yoke/`

Pulled into scope (also write `docs/ai/`, no other slice owns them — decision below):

- `skills/plan/SKILL.md:23,124,211,216,235,247,248` + `skills/plan/examples/*.md`
- `skills/task/SKILL.md:134,136,197,202,219,231,232` + `skills/task/examples/*.md`
- `skills/explore/SKILL.md:134,139` + `skills/explore/agents/explore-log-writer.md:37,46,77`
- `skills/fix/SKILL.md:227` + `skills/fix/agents/fix-context-collector.md:44,45,75,92,93,94` + `skills/fix/agents/fix-log-writer.md:53,62,74,86` + `skills/fix/reference/fix-log-format.md:12`
- `skills/help/SKILL.md:16,28,31,38,41,48,91,102,121,123,133,143` — prose describing every skill's artifact I/O

**Glossary + ADR references (migrate to `.yoke/context.md` / `.yoke/adr/`):**

- `skills/grill-docs/reference/domain-docs.md:7,8,9,15`
- `skills/grill-docs/reference/ADR-FORMAT.md:3,5,27`
- `skills/grill-docs/reference/CONTEXT-FORMAT.md:1,37,46-48,60-61`

**Non-markdown code path:**

- `lib/pr-collect.sh:50,51,53` — resolves `docs/ai/$SLUG/...` and `ls -td docs/ai/*/`; the only shell script affected. Update to `.yoke/ai/`.

**ADR files to `git mv` into `.yoke/adr/`:**

- `docs/adr/0001-docs-site-on-astro-starlight.md`, `0002-sync-docs-skill.md`, `0003-direct-telegram-notify.md`, `0004-yoke-artifact-root.md`, `0005-do-universal-orchestrator.md`

**Docs:**

- `README.md:186,188,262,267,278` (hand-edit) and rows `61,65,68` (sentinel-managed — regenerate via `/sync-docs`, do not hand-edit). Add a new section documenting the `.yoke/` convention.
- `CLAUDE.md:93,103` (hand-edit) and rows `71,75,78` (sentinel-managed). Add the `.yoke/` convention to the Architecture/Conventions section.
- `.gitignore:2` — narrow `.yoke` to `.yoke/sync-docs-tmp/` + `.yoke/notify-pending.json` (decision below).
- `skills/sync-docs/reference/sync-spec.md:93` — asserts "`.yoke/` is gitignored"; update to reflect the narrowed ignore.

### Patterns to reuse

The literal-path pattern is uniform — replace the prefix in place:

```
Save a local copy to `docs/ai/<slug>/<slug>-prd.md` (`mkdir -p docs/ai/<slug>` first).
```

becomes `.yoke/ai/<slug>/<slug>-prd.md` (`mkdir -p .yoke/ai/<slug>`). Agent shell vars follow the same shape (`skills/explore/agents/explore-log-writer.md:37`):

```
EXPLORATION_LOG="docs/ai/{{SLUG}}/{{SLUG}}-exploration.md"
```

The sentinel-managed catalog rows in README/CLAUDE.md are generated from each SKILL.md `description` between `<!-- yoke:skills:start -->` markers — fix the descriptions, then run `/sync-docs` to regenerate. `lib/notify.sh` already uses `.yoke/notify-pending.json` correctly — reuse it as the reference for `.yoke/`-relative paths in shell.

### Tests

No automated test suite for skill markdown. Validation is the manual checks in this file plus `pnpm run format:check` and the JSON/YAML validators in CLAUDE.md. Coverage gap: there is no grep guard preventing a stray `docs/ai`/`docs/adr`/root-`CONTEXT.md` reference from reappearing — the verification grep below is the substitute.

## Requirements

1. Every artifact path in the listed skills resolves under `.yoke/`: `.yoke/ai/<slug>/` for pipeline artifacts, `.yoke/context.md` for the glossary, `.yoke/adr/` for ADRs, `.yoke/journal.md` for the journal.
2. Migrate **all skills that write `docs/ai/`** in this slice: the seven ticketed ones (`grill-docs`, `grill`, `prd`, `issues`, `review`, `gca`, `handoff`) **plus `plan`, `task`, `explore`, `fix`** — so the "no skill writes to `docs/ai/`" criterion holds. Only `do`, `journal`, `bootstrap` are left to their own slices.
3. Update `skills/help/SKILL.md` prose so `/help` reports `.yoke/` locations accurately.
4. Update `lib/pr-collect.sh` to resolve `.yoke/ai/$SLUG/` so `/pr` artifact discovery keeps working.
5. Collapse the glossary to a **single `.yoke/context.md`**: retire the `CONTEXT-MAP.md` + per-context split in `grill-docs` and `CONTEXT-FORMAT.md`; the glossary is one file.
6. `git mv` ADRs `0001`–`0005` from `docs/adr/` into `.yoke/adr/`; `docs/adr/` no longer holds them.
7. Delete the `.gitignore`-probing logic in `skills/review/SKILL.md:160` (and any equivalent in the migrated skills). Skills always write to `.yoke/` and commit unless `.yoke/` is ignored — keep only that single "is `.yoke/` ignored?" escape-hatch check, not a per-location probe.
8. Narrow this repo's `.gitignore`: ignore only `.yoke/sync-docs-tmp/` and `.yoke/notify-pending.json`, so dogfooded artifacts are tracked here like in a target project. Update `skills/sync-docs/reference/sync-spec.md:93` to match.
9. Document the `.yoke/` convention in `README.md` (new section) and `CLAUDE.md`; regenerate sentinel-managed catalog rows via `/sync-docs` after editing SKILL.md descriptions.

## Constraints

- Do not migrate `do`, `journal`, or `bootstrap` — they adopt the convention in S3/S4/S5. Leave their `docs/ai` / `docs/adr` / root-`CONTEXT.md` references untouched (`skills/do/SKILL.md`, `skills/bootstrap/SKILL.md`, `.claude/commands/journal.md`).
- Do not hand-edit the catalog rows between `<!-- yoke:skills:start -->` markers in README/CLAUDE.md — they are overwritten by `/sync-docs`. Edit SKILL.md descriptions instead.
- Do not fully ignore `.yoke/` again — only the two scratch paths stay ignored.
- Keep `lib/notify.sh` as is — it already targets `.yoke/notify-pending.json`.
- Do not invent a manifest or config file — the convention is fixed paths (per ADR 0004), no parsing.
- Change the path prefix only — do not restructure the artifacts, filenames, or skill logic beyond the glossary collapse in requirement 5.
- ADR 0004's own body still describes `docs/adr/` for continuity — that is the historical record; move the file but do not rewrite its prose to claim it was always in `.yoke/`.

## Verification

- `grep -rn "docs/ai" skills/ lib/ README.md CLAUDE.md` → only matches inside `skills/do/`, `skills/bootstrap/`, and `.claude/commands/` (the deferred slices); no match in any migrated skill, `lib/pr-collect.sh`, README, or CLAUDE.md.
- `grep -rn "docs/adr" skills/ README.md CLAUDE.md` → no matches except inside the moved ADR 0004's historical prose.
- `grep -rn "CONTEXT-MAP\|root CONTEXT.md\|\`CONTEXT.md\`" skills/grill-docs/` → no live glossary references to the root or the map split.
- `ls .yoke/adr/` → shows `0001`–`0005`; `ls docs/adr/` → empty or absent.
- `cat .gitignore` → ignores `.yoke/sync-docs-tmp/` and `.yoke/notify-pending.json` only, not all of `.yoke`.
- Run `/yoke:prd`, `/yoke:plan`, `/yoke:task`, `/yoke:review` on a sample slug → each artifact lands at `.yoke/ai/<slug>/...` and gets committed (because `.yoke/` is no longer ignored).
- Run `/yoke:grill-docs` → glossary written to `.yoke/context.md`, ADR to `.yoke/adr/`.
- `bash lib/pr-collect.sh` (or invoke `/pr`) on a slug with `.yoke/ai/<slug>/` artifacts → discovers and collects them.
- `/help` output names `.yoke/` paths, not `docs/ai`/`CONTEXT.md`.
- `pnpm run format:check` → passes; JSON/YAML validators in CLAUDE.md → `OK`.
- `/yoke:sync-docs --check` → no drift after catalog regeneration.

## Materials

- [Issue #18 — S1 .yoke/ artifact convention](https://github.com/yokeloop/yoke/issues/18)
- [Epic #17 — yoke 2.0 Global Refactor](https://github.com/yokeloop/yoke/issues/17)
- `docs/adr/0004-yoke-artifact-root.md` — source-of-truth convention
- `lib/pr-collect.sh` — `/pr` artifact discovery (lines 50–53)
- `lib/notify.sh` — reference for `.yoke/`-relative shell paths
- `skills/grill-docs/reference/{domain-docs,ADR-FORMAT,CONTEXT-FORMAT}.md` — glossary/ADR consumer rules
- `.gitignore` (line 2) — current full `.yoke` ignore to narrow
