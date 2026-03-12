---
name: pr-review
description: 'Analyzes a GitHub pull request and generates a structured report comparing changes against the implementation plan, design document, and start prompt. Highlights unauthorized architectural decisions by the model, unnecessary abstractions, and simplification opportunities. Use this skill whenever the user mentions PR review, PR analysis, PR report, pull request review, or wants to understand what changed in a PR and whether it follows the plan. Trigger even if the user just pastes a GitHub PR URL.'
argument-hint: <github-pr-url>
---

# PR Review Report Generator

Generates a structured review report for a GitHub pull request. The report ties every change back to the project's implementation plan, design document, and start prompt stored in `.agents/`. The goal: surface places where the AI model went off-plan, over-engineered, or introduced unnecessary complexity.

## Why this matters

When an AI model implements a plan, it often adds code that nobody asked for — extra abstractions, wrapper functions, unnecessary refs, auto-sync logic. These additions increase complexity without adding value. This skill systematically finds them by comparing what was planned against what was actually committed.

## Input

`$ARGUMENTS` contains the PR URL. Format: `https://github.com/owner/repo/pull/123`

If no argument is provided, stop and show:

```
Usage: /pr-review https://github.com/owner/repo/pull/123
```

## Process

### Step 1. Collect PR data

Gather all information needed for analysis. Run these in parallel:

```bash
# PR metadata
gh pr view <URL> --json number,title,body,baseRefName,headRefName,additions,deletions,commits

# Changed files with stats
gh pr view <URL> --json files --jq '.files[] | "\(.path)\t+\(.additions)\t-\(.deletions)"'

# Full diff
gh pr diff <URL>
```

Also read the project's `CLAUDE.md` — it defines the architecture, code conventions, and directory structure. This context is essential for evaluating whether changes fit the codebase.

You can supplement with local git commands (`git log`, `git diff`) if the branch is checked out locally. Use whatever gives the most complete picture.

### Step 2. Find related documents

The project stores plans and prompts in `.agents/`. Search for documents related to this PR's topic:

**Start prompt** — `.agents/prompts/<topic>.md`
Match by topic keyword from the PR title or branch name. Example: branch `R2-6-analytics` or title containing "analytics" → look for `analytics.md`, `stats.md`, or similar.

**Design document** — `.agents/plans/YYYY-MM-DD-<topic>-design.md`
Search by topic and by references in the PR description.

**Implementation plan** — `.agents/plans/YYYY-MM-DD-<topic>-implementation.md`
Usually paired with the design document (same date prefix and topic).

If a document is not found, record "Not found" in the report metadata. Do not stop the analysis — the report is still valuable without these documents.

### Step 3. Analyze changes

Read each changed file **in full** (not just the diff). The diff shows what changed; the full file shows whether the change makes sense in context.

Perform four analyses:

#### Plan compliance

Walk through each item in the implementation plan. For each:

- Was it implemented? Mark as Done / Partial / Skipped / Deviated.
- If deviated — what was done instead and why might the model have chosen differently?
- If skipped — was it intentionally deferred or forgotten?

#### Unauthorized model decisions

Find code that is NOT in the plan and was added by the model on its own initiative. Common patterns:

- Extra abstraction layers (wrappers, adapters, utility functions for one-time operations)
- Premature generalization (config options nobody asked for, extensibility points)
- Defensive code for impossible scenarios (error handling for cases that can't happen)
- Auto-sync, auto-retry, caching logic not in requirements
- State management complexity (useRef/useState where a simple variable suffices)
- React patterns copied from tutorials but unnecessary here (extra contexts, memoization)

For each finding, assess: is this addition justified, or is it pure over-engineering?

#### Architectural impact

Evaluate the blast radius of changes:

- New dependencies added to package.json
- Changed interfaces or type definitions in shared code
- New IPC channels
- Modified preload APIs
- New files vs modified existing files

#### Simplification opportunities

Find places where the implementation can be made simpler:

- Code that duplicates existing functionality
- Dead code or unused exports
- Wrappers that add no value (pass-through functions, trivial adapters)
- Complex patterns where a simple approach works (useRef where a plain variable works, useState where a prop suffices, useCallback where identity stability doesn't matter)

## Report structure

Write the report in Russian. Use clear, direct language — short sentences, no filler.

### Header

```markdown
# PR Review Report: <PR title>

**Date:** YYYY-MM-DD
**PR:** <full PR URL>
**Branch:** <headRefName> → <baseRefName>
**Commits:** <count>
**Start Prompt:** <relative path or "Not found">
**Design Doc:** <relative path or "Not found">
**Implementation Plan:** <relative path or "Not found">
```

### 1. Files Changed

Table of changed files, sorted by total changes (additions + deletions) descending:

| File                            | +lines | -lines | Description                        |
| ------------------------------- | ------ | ------ | ---------------------------------- |
| relative path from project root | N      | N      | one sentence: what changed and why |

### 2. Summary

Key architectural decisions in the PR. Each as a separate bullet:

- What was done (with file references like `path/to/file.ts:42`)
- Why (architectural reasoning)
- Focus on: API/interface changes, new patterns, dependency choices

### 3. Attention Points

Specific places that need reviewer attention. Include only items that matter:

- High cyclomatic complexity or convoluted logic
- Code duplication
- Unnecessary abstractions (wrappers without value, premature generalization)
- Unplanned decisions — code not in the plan where the model made an architectural choice on its own

Format each point with: file path, line range, what the problem is, why it matters.

### 4. Improvement Suggestions

For each Attention Point: 2-3 concrete simplification options. Include brief code examples (up to 15 lines) or describe the approach.

### 5. Plan Compliance

Table mapping each plan item to its implementation status:

| Plan Item                | Status                              | Notes       |
| ------------------------ | ----------------------------------- | ----------- |
| description of plan item | Done / Partial / Skipped / Deviated | explanation |

After the table — a paragraph with overall assessment: how closely does the implementation follow the plan? Are there systematic deviations?

## Code reference format

When referencing code in the report, use this format:

`<branch>/<relative-path>` - from line N to M

```<language>
<code snippet>
```

Example:

`R2-6-analytics/src/renderer/src/app/App.tsx` - from line 49 to 53

```tsx
<AnalyticsProvider initialSessionId={sessionId}>
  <div className="app">
    <MainPage />
  </div>
</AnalyticsProvider>
```

## Output

Save the report to: `.agents/reports/YYYY-MM-DD-<topic>-pr-review.md`

- `YYYY-MM-DD` — today's date
- `<topic>` — keyword from PR title in kebab-case (e.g., `analytics`, `password-refactor`, `ci-cd`)

After saving, print the report path and a one-line summary of the most important finding.
