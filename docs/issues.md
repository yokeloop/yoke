# Skill /issues

Breaks a plan, spec, or PRD into independently-grabbable GitHub issues using vertical slices (tracer bullets), publishes them in dependency order, and saves a local index.

## Input

`$ARGUMENTS` (optional) — an issue reference (number, URL, or path) to break down. Otherwise works from the conversation context.

```
/yoke:issues
/yoke:issues https://github.com/owner/repo/issues/42
```

## Process

| Step | What happens                                                          |
| ---- | --------------------------------------------------------------------- |
| 1    | Gather context (fetch the referenced issue if given)                  |
| 2    | Explore the codebase; follow domain-doc consumer rules                |
| 3    | Draft vertical slices (tracer bullets), each cutting through layers   |
| 4    | Quiz the user on granularity, dependencies, HITL/AFK — until approved |
| 5    | Publish in dependency order; save a local index                       |

## Vertical slices

Each slice is a thin, end-to-end path through ALL layers (schema, API, UI, tests), not a horizontal layer. A completed slice is demoable on its own. Prefer many thin slices. Slices are marked **AFK** (mergeable without a human) or **HITL** (needs human input) — prefer AFK.

## Output

- `.yoke/ai/<slug>/<slug>-issues.md` — local index: title, type, blocked-by, issue URL, and body for each slice.
- GitHub issues (when `gh` is available), labelled `ready-for-agent`, published blockers-first so "Blocked by" cites real issue numbers. See [github-issues.md](../skills/issues/reference/github-issues.md). Falls back to local-only otherwise.

Does not close or modify any parent issue.

## Connections

Spec → tracker. Run after `/yoke:prd` or `/yoke:plan` to turn a spec into grabbable tickets; pick one up with `/yoke:task`.
