# Changelog

## 2.0.0 — yoke 2.0 — Global Refactor

Breaking release. Epic [#17](https://github.com/yokeloop/yoke/issues/17).

### Breaking changes

- **Unified `.yoke/` artifact root** ([#18](https://github.com/yokeloop/yoke/issues/18), ADR 0004). Every artifact now lives under `.yoke/`: `.yoke/ai/<slug>/` (pipeline artifacts), `.yoke/context.md` (domain glossary, was root `CONTEXT.md`), `.yoke/adr/` (was `docs/adr/`), `.yoke/journal.md`. `.yoke/` is committed by default; only `.yoke/sync-docs-tmp/` is gitignored. Existing repos on `docs/ai/` + root `CONTEXT.md` must migrate manually.
- **`do` is the universal execution tool; `task` and `plan` removed** ([#21](https://github.com/yokeloop/yoke/issues/21), ADR 0005). `/yoke:do` auto-detects its mode from the input: a chat description → inline (no pause); a single issue → sub-agents (plans, pauses for confirmation, executes); a PRD with sub-issues → team (per-sub-issue dispatch). `task`/`plan` moved to `deprecated/`.
- **`fix`, `gst`, `explore` removed** ([#19](https://github.com/yokeloop/yoke/issues/19)). Moved to `deprecated/`, out of the shipped set.
- **`sync-docs` is now repo-internal** ([#19](https://github.com/yokeloop/yoke/issues/19)). Relocated to `.claude/skills/`; it maintains this repo's docs site and no longer ships to users.
- **No hooks; direct Telegram notifications** ([#20](https://github.com/yokeloop/yoke/issues/20), ADR 0003). `lib/notify.sh` POSTs to the Telegram Bot API inline via `curl` (no queue file, no `jq`, no Stop hook). The `hooks/` directory is removed. Flags simplified to `--type`/`--title`/`--body`/`--skill`.

### Added

- **`/yoke:journal`** ([#22](https://github.com/yokeloop/yoke/issues/22)). A shipped skill that appends a concise, newest-first entry to `.yoke/journal.md`, linking the session's `.yoke/ai/<slug>/` artifacts — the first layer of yoke's connected memory.

### Changed

- **`bootstrap` scaffolds `.yoke/`** ([#23](https://github.com/yokeloop/yoke/issues/23)). A fresh bootstrap creates the `.yoke/` skeleton (`context.md`, `journal.md`, `ai/`, `adr/`), seeds the glossary from stack detection, and wires `CLAUDE.md` to the `.yoke/` conventions.
- Shipped skill set reduced from 18 to **13**: `bootstrap`, `do`, `gca`, `gp`, `grill`, `grill-docs`, `handoff`, `help`, `issues`, `journal`, `pr`, `prd`, `review`.
- `README.md`, `CLAUDE.md`, and the public catalog updated to the `.yoke/` convention and the smaller set.

### Migration

This is a 2.0.0 breaking change with no automatic migration of pre-existing repos. To adopt: move `docs/ai/<slug>/` → `.yoke/ai/<slug>/`, root `CONTEXT.md` → `.yoke/context.md`, `docs/adr/` → `.yoke/adr/`; replace `/yoke:task` + `/yoke:plan` usage with `/yoke:do`; set `CC_TELEGRAM_BOT_TOKEN`/`CC_TELEGRAM_CHAT_ID` if you want notifications.
