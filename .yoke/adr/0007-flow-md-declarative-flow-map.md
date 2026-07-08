# .yoke/flow.md — a declarative per-project flow map read by every skill

Every project has its own finish rules (velvetnet: app via PR, ui-kit via
direct push + publish + consumer bump; TB-FF: three repos, PR everywhere, then
release both; branch cascades master → staging → develop; YouTrack vs GitHub
issues), and the user had to re-dictate them every session or patch them into
per-project agent memory. We decided (2026-07-08): a new committed artifact
`.yoke/flow.md` declares the linked repos and their roles (app/library), each
repo's finish policy (`pr` | `direct-push`), the branch cascade, deploy/release
commands, the ticket tracker, and the local-only choice for `.yoke/` itself.
Bootstrap generates it, grill refines it, and every skill (do, merge, gca, gp,
pr) reads it instead of asking.

Rejected: free-text rules in CLAUDE.md (unstructured, mixed with everything
else) and extending `.yoke/context.md` (the glossary is deliberately
implementation-free). Being committed, flow.md works for the whole team, unlike
agent memory which is per-machine and per-user.
