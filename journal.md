# yoke change journal

Session change log for the yoke repo, newest-first. Maintained by the `/journal` local command.

## 2026-05-24

### 22:42 MSK — Add /journal local command

**What done:** Added a repo-local `/journal` command that appends per-session summaries of real changes (with mandatory date/time) to this file. Grilled the design via `/yoke:grill-docs`: local command (not a marketplace skill), English entries, dotfiles-style field set, newest-first ordering, write-only (no auto-commit). Then refined it in two passes: tightened the prose with the elements-of-style (Strunk) skill, and validated it against plugin-dev command conventions — shortened `description` to under 60 chars and set `disable-model-invocation: true` (manual-only).
**Files:** `.claude/commands/journal.md`, `journal.md`, `CLAUDE.md`
**Why:** Wanted a durable, diggable record of what/where/why changed across yoke dev sessions, modeled on the user's `~/dotfiles/.claude/commands/journal.md`.
**Notes:** Deviates from the dotfiles original in three ways: newest-first (dotfiles grows newest-last), English entries (dotfiles is Russian), output committed to the repo root.
**Rejected:** Porting it as a marketplace skill `skills/journal/` → `/yoke:journal` — kept it repo-local since journaling is an explicit dev action, not a product feature. Auto-commit on write — kept journaling separate from git, commits go through `/gca`.
**Verify/rollback:** Run `/journal` in a session with real changes; it should prepend a new entry under today's date. Roll back by deleting `.claude/commands/journal.md` and this file.
**Commit:** not committed
