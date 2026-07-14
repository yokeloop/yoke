# Commit messages as the git memory layer

Every yoke run loses its Decision Shadow — the constraints, rejected
alternatives, and reasoning that lived in the agent's head when the code was
written. We decided (2026-07-13, issue #2): the commit message itself is the
memory channel. The existing subject convention (`TICKET type(SLUG):
description`) stays; beneath it, commits that carry a decision get a prose
body explaining _why_ (written for coding agents as the primary readers, since
humans rarely look) plus optional decision trailers from a fixed vocabulary of
four: `Constraint:`, `Rejected:`, `Directive:`, `Related:`. The body is
required by content, not by type — the test is "will a reader six months out
wonder why", so mechanical chore/style commits stay one-liners. The read side
is symmetric: every skill that touches or judges code (do, draft, review,
grill, grill-docs, prd, issues) reads the history of the affected files before
working. Both guides live in `skills/gca/reference/` (the owning-skill
precedent); bootstrap distributes the convention to target projects as a
compact CLAUDE.md section — always-on for any agent. Enforcement is
behavioral, not infrastructural (revised 2026-07-14): agents do the
committing, so the convention lives in the instructions the committing agent
follows; there is no git hook. The ticket cascade keeps its current softness:
no ticket found → commit without one. The ban on trailers is narrowed to
identity trailers (`Co-Authored-By`, `Signed-off-by`); decision trailers are
the point.

Considered and rejected: the full Lore Protocol from arXiv:2603.15566 as
specified in issue #2 — a `lore/` skill, a `lore-init/` scaffolder, and nine
trailers (`Confidence:`, `Scope-risk:`, `Reversibility:`, `Tested:` degrade
into ritual self-assessment noise; a separate skill adds surface where an
evolved convention suffices); trailers-only structure (models read prose
better than key-value fragments); prose-only bodies (lose `git log` grep by
trailer key, the cheap read-side filter); a body required on every commit or
by commit type (both manufacture water in trivial commits); a `commit-msg`
git hook in any form (shipped in v3.1.0, removed same day: the user gutted it
immediately — per-repo hook infrastructure is noise when agents are the ones
committing, and a hook cannot judge content anyway); markdown files as the
memory medium (a parallel artifact tree duplicating what git already
versions — the field is right there).
