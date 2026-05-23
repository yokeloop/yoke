# GitHub issue tracker

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations — it infers the repo from `git remote -v` when run inside a clone.

## Preconditions

- `gh auth status` succeeds (authenticated), and
- `gh repo view` succeeds (the repo has a GitHub remote).

If either fails, skip publishing: keep the local copy in `docs/ai/<slug>/` and tell the user where it is.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body-file <path>`. Use `--body-file` for multi-line bodies (write the body to a temp file or a `docs/ai/` artifact first).
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

## Semantics

- "Publish to the issue tracker" → create a GitHub issue.
- "Fetch the relevant ticket" → `gh issue view <number> --comments`.
