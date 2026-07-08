# The flow ends at PR: do drives to it, merge is a separate user command

Log analysis of a month of real usage (78 sessions, 17 projects) showed the
pipeline lives as grill → do, and everything after — commit, push, PR, merge,
cascade merges, deploy, ticket transitions — was dictated by hand almost
verbatim in 20+ sessions; only 6 of 45 do-sessions reached git-finish through
skills. We decided (2026-07-08): `do` always finishes its run — enters a
worktree when started on the default branch, commits, pushes, opens the PR(s)
per each repo's finish policy, comments on the ticket — and stops there. The
merge decision stays with the user on GitHub; a single `/merge` finisher
executes the whole post-PR tail (merge, cascades, deploy/release, ticket
transition, worktree cleanup) on explicit command.

Considered and rejected: keeping review/gca/gp/pr as manual default-path steps
(the observed funnel gap), making PR conditional on a flag (the PR _is_ the
deliverable), and auto-merging (violates the user's control point — "не мержи"
appears repeatedly in logs). The plan-confirmation pause survives only on cold
start — a `do` with no preceding grill and no approved plan. review/gca/gp/pr
remain as standalone utilities outside the default path.
