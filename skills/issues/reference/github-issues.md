# GitHub issue tracker

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations — it infers the repo from `git remote -v` when run inside a clone.

## Preconditions

- `gh auth status` succeeds (authenticated), and
- `gh repo view` succeeds (the repo has a GitHub remote).

If either fails, skip publishing: keep the local copy in `.yoke/ai/<slug>/` and tell the user where it is.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body-file <path>`. Use `--body-file` for multi-line bodies (write the body to a temp file or a `.yoke/ai/` artifact first).
- **Read an issue**: `gh issue view <number> --comments`.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with `--label` / `--state` filters as needed.
- **Comment**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

## Triage labels

The skills speak in five canonical triage roles. By default each role's label string equals its name:

| Role              | Meaning                                                                  |
| ----------------- | ------------------------------------------------------------------------ |
| `needs-triage`    | Maintainer needs to evaluate this issue                                  |
| `needs-info`      | Waiting on reporter for more information                                 |
| `ready-for-agent` | Fully specified, ready for an AFK agent to pick up with no human context |
| `ready-for-human` | Requires human implementation                                            |
| `wontfix`         | Will not be actioned                                                     |

If the repo already uses different label names for these roles (check `gh label list`), map to those instead of creating duplicates.

## Applying `ready-for-agent`

PRDs and tracer-bullet issues are written to be AFK-ready, so publish them with `ready-for-agent` unless the user says otherwise:

1. `gh label list --json name --jq '.[].name'` — does `ready-for-agent` (or the repo's mapped equivalent) already exist?
2. If it exists, apply it at create time: `gh issue create ... --label ready-for-agent`.
3. If it doesn't, create it once, then apply:
   `gh label create ready-for-agent --description "Fully specified, ready for an AFK agent" --color 0E8A16`
4. If label creation is declined or fails, publish without the label and note it to the user.

## Issue types

GitHub issue **types** (`Bug`, `Feature`, `Task`, or org-defined ones) are a field separate from labels and render distinctly in the UI. Organizations define them; personal repos and orgs without them configured have none. The `gh` CLI exposes no flag for types (through 2.92), so set them through the REST API.

Set the type as a best-effort step _after_ the issue exists — never as a create-time flag — so the issue always lands even when typing fails:

```bash
gh api --method PATCH "/repos/{owner}/{repo}/issues/<number>" -f type="Feature"
```

`gh` fills `{owner}`/`{repo}` from the current repo; take `<number>` from the trailing segment of the URL that `gh issue create` prints. If the call errors (the account has no issue types, the type name is undefined, or the token lacks permission), leave the issue untyped and tell the user the type wasn't set and why. Do not substitute a label — the type and labels are independent.

## Sub-issues

GitHub **sub-issues** form a parent/child relationship between issues (e.g. a `Feature` parent grouping `Task` children) and render as a structured tree in the UI. The `gh` CLI exposes no sub-issue subcommand, so set the link through the REST API.

Linking a child to a parent needs two things: the **parent's issue number** and the **child's REST id** — an integer, _not_ the issue number. Retrieve the child's id after creating it:

```bash
child_id=$(gh issue view <child_number> --json id --jq .id)
```

Then attach the child to the parent:

```bash
gh api --method POST "/repos/{owner}/{repo}/issues/<parent_number>/sub_issues" \
  -f sub_issue_id="$child_id"
```

Treat the link as a best-effort step after the child exists. If the call errors (sub-issues unavailable on this repo plan, parent not found, missing permission), leave the child unlinked and tell the user why. The textual `## Parent` reference in the issue body remains the human-readable fallback.

## Semantics

- "Publish to the issue tracker" → create a GitHub issue.
- "Fetch the relevant ticket" → `gh issue view <number> --comments`.
