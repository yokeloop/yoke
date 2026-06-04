# Sync spec

The contract `/yoke:sync-docs` honours. Read this before changing the
skill or the renderer.

## Sentinel rules

Open marker: `<!-- yoke:skills:start -->`
Close marker: `<!-- yoke:skills:end -->`

For each target file (`README.md` and `CLAUDE.md`):

- Exactly one **standalone-line** open marker and one standalone-line close marker must exist. Match with `^<!-- yoke:skills:start -->$` and `^<!-- yoke:skills:end -->$`. Occurrences of the marker text inside table cells, code blocks, or other inline content do not count — the catalog itself often mentions the markers in the sync-docs row, and that is by design.
- The standalone open marker line must precede the standalone close marker line.
- Sync writes only the byte range strictly between the two standalone markers. Every byte outside that range round-trips unchanged.

When any of those preconditions fails, the skill aborts before any write
and reports:

```
Markers missing or unbalanced in <file>.
Add exactly one <!-- yoke:skills:start --> and one <!-- yoke:skills:end -->
around the catalog block; re-run.
```

In `--check` mode this is a non-green exit. In write mode this is a refusal
to write. Sync never auto-inserts the markers — they are added once by hand
in the PR that introduces sync-docs (PRD #15).

## Enumeration rule

The shipped catalog includes:

- Every directory under `skills/<name>/` that contains a `SKILL.md`.

The shipped catalog excludes:

- Every directory under `.claude/skills/<name>/`. These are local-only
  development tools (`yoke-create`, `yoke-release`, `yoke-validate`) and
  must never appear on the public site, in the `README.md` table, or in
  the `CLAUDE.md` `## Implemented skills` block.

The current shipped catalog is 17 skills:
`bootstrap, do, explore, fix, gca, gp, grill, grill-docs, gst, handoff,
help, issues, journal, pr, prd, review, sync-docs`.

## Check-mode contract

`/yoke:sync-docs --check` performs the full Render phase against
`.yoke/sync-docs-tmp/`, then compares:

1. `.yoke/sync-docs-tmp/skills/<name>.mdx` vs `site/src/content/docs/skills/<name>.mdx` for every shipped skill.
2. `.yoke/sync-docs-tmp/readme-block.md` vs the byte range between sentinels in `README.md`.
3. `.yoke/sync-docs-tmp/claudemd-block.md` vs the byte range between sentinels in `CLAUDE.md`.

Any difference (presence, absence, or byte-level mismatch) is drift. The
skill lists every affected file (newline-separated) and exits non-green.

`/yoke-release` invokes `--check` as its `0f. Docs drift gate` step. On drift,
the release halts and the author runs `/yoke:sync-docs`, reviews, commits,
and retries.

## Idempotence rule

Running `/yoke:sync-docs` followed by `/yoke:sync-docs --check` produces no
diff. `git diff --stat` between the two calls is empty.

Both modes pipe their output through `prettier --write` before writing or diffing — husky's `lint-staged` would do the same on the next commit, so canonical prettier output is the round-trip target. Skipping prettier breaks idempotence the moment a commit lands.

When the second call reports drift after a fresh write, the renderer is non-deterministic — fix the renderer first. Do not paper over with `--no-verify` or commits between calls.

## Side-channel rule

Sync writes only to:

- `site/src/content/docs/skills/<name>.mdx`
- The byte range between sentinels in `README.md`
- The byte range between sentinels in `CLAUDE.md`

Sync never touches:

- `site/astro.config.mjs` — sidebar grouping is human-curated.
- `site/src/content/docs/index.mdx` — landing page is human-written.
- `site/src/content/docs/{what-is-yoke,install,concepts}.mdx` — generic
  pages are human-written.
- `docs/<name>.md` — per-skill long-form docs are source material.
- `skills/<name>/SKILL.md` — the source of truth.

## Workspace contract

Sync expects:

- `.yoke/sync-docs-tmp/` is gitignored (it is, per `.gitignore`).
- `site/src/content/docs/skills/` exists as a directory.

When `site/src/content/docs/skills/` is missing, sync creates it before
the first write.
