# Report Format

The single home of the `/do` report template. Format of the output file
`<slug>-report.md`, written at finish (Phase 6). Every mode renders this same
template, then appends the Finish block from `finish.md` §7.

---

## Template

```markdown
# Report: <slug>

**Plan:** <path to the plan file>
**Mode:** <actual mode (inline | sub-agents | team)>
**Status:** ✅ complete | ⚠️ partial | ❌ failed

## Tasks

| #   | Task       | Status                | Commit    | Concerns          |
| --- | ---------- | --------------------- | --------- | ----------------- |
| 1   | <name>     | ✅ DONE               | `abc1234` | —                 |
| 2   | <name>     | ⚠️ DONE_WITH_CONCERNS | `def5678` | see below         |
| 3   | <name>     | ❌ BLOCKED            | —         | see below         |
| 4   | <name>     | ⏭️ SKIPPED            | —         | depends on Task 3 |
| 5   | Validation | ✅ DONE               | `ghi9012` | —                 |

## Post-implementation

| Step          | Status  | Commit    |
| ------------- | ------- | --------- |
| Validate      | ✅ pass | —         |
| Documentation | ✅ done | `ccc3333` |
| Format        | ✅ done | `ddd4444` |

## Concerns

### Task 2: <name>

<concerns text from the sub-agent>

## Blocked

### Task 3: <name>

**Reason:** <block reason>
**Impact:** Task 4 skipped (depends on Task 3)

## Validation

<lint command> ✅
<type-check command> ✅ (or N/A if not applicable)
<test command> ✅ (<N> passed, 0 failed)
<build command> ✅ (or N/A if not applicable)

## Changes summary

| File                        | Action   | Description                        |
| --------------------------- | -------- | ---------------------------------- |
| src/auth/forgot-password.ts | created  | POST /auth/forgot-password handler |
| src/auth/reset-password.ts  | created  | POST /auth/reset-password handler  |
| src/routes/auth.ts          | modified | Added new routes                   |

## Commits

- `abc1234` feat(112-password-reset): forgot-password endpoint
- `def5678` feat(112-password-reset): reset-password endpoint
- `ghi9012` test(112-password-reset): endpoint tests
- `jkl3456` chore(112-password-reset): validation
- `ccc3333` docs(112-password-reset): update documentation
- `ddd4444` chore(112-password-reset): format

## Finish

| repo | branch | PR URL / published version |
| ---- | ------ | -------------------------- |
```

---

## Status derivation

Status is derived from the tasks:

- All DONE → `✅ complete`
- Some BLOCKED or SKIPPED, but the majority DONE → `⚠️ partial`
- Majority BLOCKED → `❌ failed`

## Rules

- Render the **Concerns** and **Blocked** sections only when there are matching tasks.
- **Changes summary** — collect from the FILES_CHANGED of all sub-agents.
- Commits in chronological order, including post-implementation.
- **Finish** — one row per touched repo (`finish.md` §7). Aggregate every PR URL and
  every published version across all touched repos into the table. The run-level notify
  carries the PR link(s) as its payload — the developer returns on that notification, so
  do not also fire the pr skill's own notify.
