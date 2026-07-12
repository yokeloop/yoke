# Draft: an optional marking step between grill and do, one PR from markup to ready

The flow lacked a control point where the user sees the picture _in the code_
before implementation runs: the plan artifact describes intent, but only the
diff shows where the change actually lands. We decided (2026-07-12): a
separate skill `/draft` — a do-shaped run with do's input contract and finish
machinery — that projects the plan onto the code as markup (`TODO(yoke): …`
markers in existing files plus a skeleton of new files, signatures, and types
with compilable stub bodies) and opens a GitHub **draft** PR instead of
implementing. The user reviews that PR remotely and comments; `/do` then
executes in the same branch and same PR, treating PR comments as the
strongest voice (comments > markers > plan), implementing markers as a
checklist — each marker deleted with its implementation, a final grep gating
the finish — replying in every comment thread with what it did, and flipping
the PR to ready. Draft never pauses (the draft PR _is_ the pause) and is
iterable: a re-run reads the comments and re-marks in the same branch. The
step is optional; grill → do stays the default path and ADR-0006 stands.

Considered and rejected: a `/do --draft` mode (do's contract is "drive to a
ready PR"; a flag inverts its semantics and is easy to forget), a fresh PR
for the implementation (cleaner final diff, but review comments detach from
the code they anchor to), comments-only markup (cannot show new structure),
a fully typed scaffold (half the implementation, accepted blind — the exact
thing draft exists to prevent), and a cold-start pause in draft (duplicates
the control the PR already provides).
