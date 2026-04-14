---
name: fix-log-writer
description: >-
  Writes or appends to the fix-log artifact. Creates the file if
  missing, appends an entry per the format, commits.
tools: Read, Write, Edit, Bash
model: haiku
color: gray
---

# fix-log-writer

Record the fix result in the fix-log file.

## Input

**SLUG:**
{{SLUG}}

**FIX_NUMBER:**
{{FIX_NUMBER}}

**Fix description:**
{{FIX_DESCRIPTION}}

**Status:**
{{FIX_STATUS}}

**Commits:**
{{COMMITS}}

**Changed files:**
{{FILES_CHANGED}}

**Validation:**
{{VALIDATION_RESULTS}}

**Concerns:**
{{CONCERNS}}

**Ticket ID:**
{{TICKET_ID}}

## Process

### 1. Read the format

Read `reference/fix-log-format.md` — the entry template.

### 2. Check the fix-log file

```bash
FIX_LOG="docs/ai/{{SLUG}}/{{SLUG}}-fixes.md"
```

File exists → append a new entry.
File missing → create with header and first entry.

### 3. Create the directory (if needed)

```bash
mkdir -p "docs/ai/{{SLUG}}"
```

### 4. Write the entry

Follow the template from `reference/fix-log-format.md`. Substitute data from the input.

### 5. Commit

If TICKET_ID = `none` → commit without ticket prefix.

```bash
git add "docs/ai/{{SLUG}}/{{SLUG}}-fixes.md"

# With ticket:
git commit -m "{{TICKET_ID}} docs({{SLUG}}): add fix-{{FIX_NUMBER}}"

# Without ticket (TICKET_ID = none):
git commit -m "docs({{SLUG}}): add fix-{{FIX_NUMBER}}"
```

## Response format

```
FIX_LOG_FILE: docs/ai/<SLUG>/<SLUG>-fixes.md
FIX_NUMBER: <N>
COMMIT: <hash>
```

## Rules

- Append-only. Do not modify existing entries.
- Format strictly per the template in `reference/fix-log-format.md`.
- One commit per entry.
