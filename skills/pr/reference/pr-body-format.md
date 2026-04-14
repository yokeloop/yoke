# PR body format

Formats, section mappings, and markers for the `pr-body-generator` agent.

## SP markers

Wrap content in markers:

```markdown
<!-- sp:start -->

...content...

<!-- sp:end -->
```

On update — replace only the content between the markers. Text outside the markers belongs to the user.

## sp_full format (review + report)

```markdown
<!-- sp:start -->

## Summary

<1-3 sentences from review "Context and goal">

## Attention

<Key areas from review — files and lines, what to look at during review>

## Design decisions

<Complex decisions from review — what was chosen and why>

## Questions

<Questions for the reviewer from review>

## Risks

<Risks from review>

## Test plan

<Manual verification from report as GitHub checkboxes>

- [ ] <scenario 1>
- [ ] <scenario 2>

## Changes

<Changes summary from report — file table>

| File | Action | Description |
| ---- | ------ | ----------- |
| ...  | ...    | ...         |

## Commits

<List of commits>

## Validation

<Validation results from report>

---

<!-- sp:end -->
```

## sp_partial format (report only)

Sections Attention, Design decisions, Questions, Risks — omit (no review).

```markdown
<!-- sp:start -->

## Summary

<Summary from report Tasks table + commits>

## Test plan

<Manual verification from report>

## Changes

<Changes from report>

## Commits

<List of commits>

---

<!-- sp:end -->
```

## fallback format (no sp artifacts)

```markdown
<!-- sp:start -->

## Summary

<Generated summary from commits>

## Changes

| File | +/- |
| ---- | --- |
| ...  | ... |

## Commits

<git log>

## Test plan

- [ ] ...

---

<!-- sp:end -->
```

## review → PR body mapping

| Review section             | PR section       |
| -------------------------- | ---------------- |
| Context and goal           | Summary          |
| Key areas for review       | Attention        |
| Complex decisions          | Design decisions |
| Questions for the reviewer | Questions        |
| Risks and impact           | Risks            |

## report → PR body mapping

| Report section         | PR section                    |
| ---------------------- | ----------------------------- |
| Tasks table (statuses) | Summary (addition)            |
| Manual verification    | Test plan (GitHub checkboxes) |
| Changes summary        | Changes                       |
| Commits list           | Commits                       |
| Validation results     | Validation                    |

## PR template integration

If `.github/pull_request_template.md` exists:

1. Fill template sections with data via heading mapping:
   - `## Summary` / `## Description` / `## What` → "Context and goal" from review
   - `## Test plan` / `## Testing` / `## How to test` → manual verification from report
   - `## Ticket` / `## Issue` / `## Related` → auto-link from ticket ID
2. Sections without a mapping — leave empty
3. Add the sp section (`<!-- sp:start/end -->`) after the template sections

## Auto-link

| Ticket ID  | Format             |
| ---------- | ------------------ |
| `#86`      | `Closes #86`       |
| `R2-208`   | `Ticket: R2-208`   |
| `PROJ-123` | `Ticket: PROJ-123` |
| none       | omit               |

## Auto-labels

| Commit type | Label         |
| ----------- | ------------- |
| feat        | enhancement   |
| fix         | bug           |
| refactor    | maintenance   |
| docs        | documentation |

Assign a label only if it exists in `AVAILABLE_LABELS`.

## Update logic

1. Get the current PR body
2. If it contains `<!-- sp:start -->` → replace the content between the markers
3. If no markers → insert the sp section before the body
4. Preserve text outside the markers
