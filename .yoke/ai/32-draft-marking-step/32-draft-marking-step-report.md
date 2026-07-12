# Report: 32-draft-marking-step

**Plan:** `.yoke/ai/32-draft-marking-step/32-draft-marking-step-plan.md`
**Mode:** sub-agents
**Status:** ✅ complete

## Tasks

| #   | Task                                                 | Status  | Commit    | Concerns |
| --- | ---------------------------------------------------- | ------- | --------- | -------- |
| 1   | Markup contract `markup-format.md`                   | ✅ DONE | `4d22d1f` | —        |
| 6   | Draft variants in `finish.md` §3                     | ✅ DONE | `c5c131a` | —        |
| 2   | Marking procedure `mode-draft.md`                    | ✅ DONE | `09f3e76` | —        |
| 4   | `/do` mode `mode-draft-execution.md`                 | ✅ DONE | `bb50def` | —        |
| 3   | `/draft` entry point `SKILL.md`                      | ✅ DONE | `2e73b0d` | —        |
| 5   | Draft execution rung in `do/SKILL.md`                | ✅ DONE | `d44dd98` | —        |
| 7   | Long-form `docs/draft.md`                            | ✅ DONE | `020f2fb` | —        |
| 8   | Draft execution row in `docs/do.md`                  | ✅ DONE | `a363640` | —        |
| 9   | Draft rows in `docs/notify.md`                       | ✅ DONE | `9eb1d93` | —        |
| 10  | `/draft` in `help/SKILL.md`                          | ✅ DONE | `b348548` | —        |
| 11  | README mermaid + prose                               | ✅ DONE | `721e5a6` | —        |
| 12  | CLAUDE.md prose                                      | ✅ DONE | `08576a3` | —        |
| 13  | Catalog regeneration (sync-docs counts + MDX/blocks) | ✅ DONE | `8631ecd` | —        |
| 14  | Validation                                           | ✅ DONE | `589afe7` | —        |

Every task passed the task-reviewer loop; review findings (all Minor/Important) were fixed in
`2171592`, `1aae3f6`, `df8200c`, and `589afe7`.

## Post-implementation

| Step          | Status                              | Commit    |
| ------------- | ----------------------------------- | --------- |
| Validate      | ✅ pass                             | —         |
| Documentation | ✅ done (in-plan tasks 7-13)        | see above |
| Format        | ✅ pass (prettier clean, hook + CI) | —         |

## Validation

- `prettier --check "**/*.{md,json}"` ✅
- JSON manifests (`plugin.json`, `marketplace.json`) parse ✅
- `head -1 skills/*/SKILL.md` — every file starts with `---` ✅
- yoke-validate lenses (Strunk + plugin-dev) over draft/do/help SKILL.md ✅ (2 LOW findings fixed in `589afe7`, 2 INFO accepted)
- MDX `<details>` blocks byte-match their SKILL.md sources (do, help, draft) ✅
- `TODO(yoke)` grep — only intentional documentation occurrences ✅

## Changes summary

| File                                        | Action   | Description                                              |
| ------------------------------------------- | -------- | -------------------------------------------------------- |
| skills/draft/SKILL.md                       | created  | `/draft` entry point: input, router, principles          |
| skills/draft/reference/mode-draft.md        | created  | Marking procedure: Plan → Mark → Draft PR + Iteration    |
| skills/draft/reference/markup-format.md     | created  | Markup contract: Marker, skeleton, build invariant, gate |
| skills/do/reference/mode-draft-execution.md | created  | Draft execution: voices, checklist, replies, ready flip  |
| skills/do/SKILL.md                          | modified | Input shape, router rung 2, Modes row                    |
| skills/do/reference/finish.md               | modified | §3 Draft variants: `--draft` create / `gh pr ready` flip |
| docs/draft.md                               | created  | Long-form doc with `**Output:**` line                    |
| docs/do.md                                  | modified | Draft execution row + Connections line                   |
| docs/notify.md                              | modified | draft STAGE_COMPLETE row + note                          |
| skills/help/SKILL.md                        | modified | `/draft` section + Full cycle optional line              |
| README.md                                   | modified | Mermaid draft node, prose, catalog row (sentinel)        |
| CLAUDE.md                                   | modified | `/draft` prose + catalog bullet (sentinel)               |
| .claude/skills/sync-docs/SKILL.md           | modified | Catalog count 14 → 15, list + draft                      |
| site/src/content/docs/skills/draft.mdx      | created  | Generated catalog page                                   |
| site/src/content/docs/skills/do.mdx         | modified | Regenerated (input bullet + details)                     |
| site/src/content/docs/skills/help.mdx       | modified | Regenerated (details)                                    |

## Commits

- `c47d81d` docs: implementation plan
- `c5c131a` feat: finish contract Draft variants
- `4d22d1f` feat: markup format contract
- `2171592` refactor: review polish (quote style, phrasing)
- `09f3e76` feat: /draft marking procedure
- `bb50def` feat: do draft-execution mode
- `1aae3f6` fix: fill all task-executor template fields
- `d44dd98` feat: route drafts to draft execution
- `2e73b0d` feat: /draft skill entry point
- `9eb1d93` docs: draft notification points
- `08576a3` docs: CLAUDE.md draft mention
- `020f2fb` docs: long-form draft doc
- `b348548` docs: /draft in help
- `a363640` docs: draft execution in do doc
- `721e5a6` docs: README flow
- `df8200c` refactor: review polish (payload wording, drafted slug)
- `6aaf52c` chore: sync-docs count 15
- `8631ecd` docs: regenerate skill catalog
- `589afe7` fix: ADR citation + post-run actor

## Finish

| repo          | branch                           | PR URL / published version               |
| ------------- | -------------------------------- | ---------------------------------------- |
| yokeloop/yoke | `worktree-32-draft-marking-step` | https://github.com/yokeloop/yoke/pull/33 |
