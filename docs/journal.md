# Skill /journal

Appends a concise, newest-first entry to `.yoke/journal.md` summarizing the
session's real work and linking the relevant `.yoke/ai/<slug>/` artifacts. The
first layer of yoke's connected memory: journal → artifacts → future git layer.
Manual trigger only — no hook.

## Input

`$ARGUMENTS` — optional focus or title for the entry.

```
/yoke:journal
/yoke:journal refactor of the auth module
```

## Output

A new sub-entry at the top of today's section in `.yoke/journal.md`:

- newest-first: latest date right after the title; newest sub-entry first within a date
- grouped by `## YYYY-MM-DD` then `### HH:MM TZ — <title>`
- fields: What done, Files, Artifacts (links to `.yoke/ai/<slug>/`), Why, Rejected, Commit
- repeated runs append rather than overwrite; an existing entry for the same work is augmented, not duplicated

## What it logs

Concrete changes and the decisions behind them — edits to skills/commands/agents/docs/code, new/deleted/renamed files, fixes and root causes, deliberately rejected alternatives. It skips discussions without changes, Q&A, dead-end diagnostics, and file reads. When nothing is worth recording, it writes nothing.

## Notes

The entry is an index into the detail, not a duplicate — it links artifacts by path instead of restating them. Staging and committing `.yoke/journal.md` is left to the user (e.g. via `/yoke:gca`).

## Connections

```
… any skill → /yoke:journal   (manual, end of session)
```
