# Cross-repo bootstrap: siblings via additionalDirectories, links instead of copies

Running bootstrap across six same-org React projects (velvetnet ×4, TB-FF ×2,
2026-07-09) showed the real cost of repo-blind onboarding is drift, not tokens:
the same org facts were re-derived independently in every repo and diverged —
the ui-kit publish command recorded three different ways across four flow.md
files, ticket target-state Review vs Staging for one YouTrack pipeline,
mutually exclusive consumers lists, and one session concluded the tracker
project didn't exist while three parallel siblings found it. A re-bootstrap
cost as much as a first run (~528k subagent tokens for a +37/−42 diff).

We decided (2026-07-09), three facets of one design:

1. **Discovery.** Siblings are found only through `additionalDirectories` in
   the project's `.claude/settings.local.json` — when it names an org directory
   or specific checkouts, that IS the user's declaration that the repos belong
   together. No new org-level artifact; without the setting bootstrap behaves
   exactly as before, so nothing changes for other users of the plugin.
2. **Reuse.** An existing `yoke-context.md` — a stack-matching sibling's on
   first bootstrap, the repo's own on re-run — is fed to the detect agents as a
   hypothesis to verify against the code, reporting differences only. Flow
   questions arrive pre-filled with the sibling's answers and collapse into one
   confirmation. Unconfirmed hypotheses never enter the artifacts, so a
   sibling's drift (the wrong-tracker conclusion) is not inherited.
3. **Representation.** Cross-repo knowledge is an index, not a canon: the Repos
   section of `.yoke/flow.md` holds, per linked repo, a role, checkout path,
   one-line description, and a pointer to its `.yoke/`. Shared facts live only
   in their fact owner (a library's publish procedure and consumers in the
   library's own flow.md); consumers link, and `/merge` follows the link.

Rejected: an org-level profile file above the repos (a new entity outside any
git repo that other developers would never maintain); silent inheritance
(fast, but propagates sibling drift); an explicit `bootstrap like ../repo`
argument as the primary path (kept possible, but the user shouldn't have to
remember it); canonicalizing shared facts across sibling flow.md files (a
strict shared rulebook nobody will keep updated — links age better than
copies).
