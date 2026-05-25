---
description: Log this session's real changes to journal.md by date
argument-hint: [optional focus/title for the entry]
allowed-tools: Bash(date:*), Bash(git log:*), Bash(git status:*), Read, Edit, Write
disable-model-invocation: true
---

You maintain the change journal for the **yoke** repository (`journal.md` at the repo root).

Current timestamp: !`date '+%Y-%m-%d %H:%M %Z'`
User focus for this entry (optional): $ARGUMENTS

## Task

Summarize what changed **in this session** and add it to `journal.md` at the repo root. The journal exists so you can later dig up _what changed, where, and why_.

## What to log

Only concrete changes to the repo and the decisions behind them:

- edits to skills / commands / agents / docs / code; new, deleted, or renamed files; config changes
- fixes and their **root causes**
- alternatives you deliberately **rejected** (so no one revisits them)

Do NOT log: discussions without changes, Q&A, dead-end diagnostics, file reads.

If an entry for this work already exists (e.g. you ran `/journal` earlier this session), augment it instead of writing a duplicate.
If nothing is worth recording, tell the user and **write nothing**.

## Language

Write entries in **English**, whatever the conversation language.

## Format

The file is **newest-first**: the latest date section comes right after the title, and within a date the newest sub-entry comes first. Group by `## YYYY-MM-DD` (date), then by `### HH:MM TZ — title` (time). Take the date and time from the timestamp above; never invent them.

Steps:

1. Read `journal.md` at the repo root. If missing, create it with the title `# yoke change journal` and a one-line note.
2. Find today's `## YYYY-MM-DD` section; if absent, add one **at the top**, right after the title.
3. Add a sub-entry `### HH:MM TZ — <short title>` at the top of today's section and fill it in. Include only the fields that apply, and keep each terse:

```markdown
### 14:32 CET — <short title>

**What done:** what exactly changed (1–3 sentences)
**Files:** `path/one`, `path/two`
**Why:** reason / context
**Notes:** non-obvious details that matter later (if any)
**Rejected:** the alternative and why you dropped it (if any)
**Verify/rollback:** how you confirmed it works / how to roll back (if applicable)
**Commit:** `<sha>` (if you committed this session — check `git log`) or "not committed"
```

Do **not** commit or stage `journal.md`; leave that to the user (e.g. via `/gca`). When done, tell the user what you added and under which date and time.
