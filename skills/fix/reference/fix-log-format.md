# Fix Log Format

Format of the `<slug>-fixes.md` file and individual entries.

---

## File header (on creation)

```markdown
# Fix Log: <SLUG>

**Task:** docs/ai/<SLUG>/<SLUG>-task.md
```

---

## Entry format

```markdown
## Fix N: <short description>

**Date:** <YYYY-MM-DD>
**Status:** done | blocked

### What changed

<1-3 sentences — what was done and why>

### Files

| File   | Action                         | Description           |
| ------ | ------------------------------ | --------------------- |
| <path> | <created / modified / deleted> | <change description>  |

### Validation

<lint/types/tests/build results>

### Concerns

<if any, otherwise omit the section>
```

---

## Commits

Record the list of commits after the Validation section:

```markdown
### Commits

- `<hash>` <message>
- `<hash>` <message>
```

---

## Rules

- Each entry starts with `## Fix N:`.
- N — sequential number (1, 2, 3...).
- Concerns section — only if present. No concerns, omit the section.
- Status: `done` or `blocked`. No emoji.
- Date: `YYYY-MM-DD` format.
