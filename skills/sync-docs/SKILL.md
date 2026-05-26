---
name: sync-docs
description: >-
  Regenerates the public skill catalog from `skills/*/SKILL.md` — per-skill MDX
  pages under `site/src/content/docs/skills/`, the table between
  `<!-- yoke:skills:start -->` markers in `README.md`, and the bullet list
  between the same markers in `CLAUDE.md`. Activates when the user writes
  "sync docs", "regenerate docs", "update the skill catalog", "rebuild docs",
  "refresh the catalog", or passes `--check` to detect drift. Refuses to
  write when sentinels are missing or unbalanced.
---

# Sync docs

Regenerate the public skill catalog from `skills/*/SKILL.md`. One source of
truth for the README catalog, the CLAUDE.md catalog, and the per-skill pages
on the docs site.

## Input

`$ARGUMENTS` — empty for write mode (default), or `--check` for drift
detection.

```
/yoke:sync-docs
/yoke:sync-docs --check
```

## Phases

The skill runs through 5 phases. No user interaction.

| Phase | Name               | What happens                                                                                        |
| ----- | ------------------ | --------------------------------------------------------------------------------------------------- |
| 1     | **Preflight**      | Verify the repo (`.claude-plugin/plugin.json` exists, `skills/` is a directory); parse `--check`    |
| 2     | **Enumerate**      | List the 17 shipped skills under `skills/` + sync-docs itself; never include `.claude/skills/*`     |
| 3     | **Render**         | Write per-skill MDX, README block, CLAUDE.md block into `.yoke/sync-docs-tmp/`                      |
| 4     | **Sentinel check** | Verify exactly one `start` and one `end` marker in each of `README.md` and `CLAUDE.md`; start < end |
| 5     | **Write or diff**  | Write mode → copy tmp tree over live; check mode → diff and exit non-green on drift                 |

## Phase 1 — Preflight

Verify the working tree is the yoke plugin repo:

```bash
test -f .claude-plugin/plugin.json && test -d skills/
```

Parse `--check` from `$ARGUMENTS`. Set `MODE=check` when present, `MODE=write`
otherwise.

Create the tmp tree:

```bash
rm -rf .yoke/sync-docs-tmp && mkdir -p .yoke/sync-docs-tmp/skills
```

## Phase 2 — Enumerate

List the shipped skills:

```bash
ls -d skills/*/ | xargs -n1 basename
```

Include every directory under `skills/` plus `sync-docs` itself (already
under `skills/`). Never include anything under `.claude/skills/` —
`yoke-create`, `yoke-release`, and `yoke-validate` are local-only tools and
must not appear in the public catalog.

The shipped catalog today is 18 skills:
`bootstrap, do, explore, fix, gca, gp, grill, grill-docs, gst, handoff, help,
issues, plan, pr, prd, review, sync-docs, task`.

## Phase 3 — Render

For each enumerated skill:

1. Read `skills/<name>/SKILL.md`. Parse the YAML frontmatter into `name` and
   `description`.
2. Extract trigger phrases — every quoted substring inside `description`
   that begins with a lowercase letter or a forward slash (e.g. `"sync
docs"`, `"--check"`).
3. Read `docs/<name>.md` when present; otherwise extract `## Input`,
   `## Output`, and the first example code block from the SKILL.md body.
4. Render the MDX page from `reference/mdx-template.md` (see that file for
   the full template) into `.yoke/sync-docs-tmp/skills/<name>.mdx`.
5. Always include the raw SKILL.md body verbatim inside a
   `<details><summary>Full instructions</summary> … </details>` block.

After every skill is rendered:

6. Render the README block to `.yoke/sync-docs-tmp/readme-block.md` as a
   3-column markdown table:

   ```markdown
   | Command        | What it does           | Output   |
   | -------------- | ---------------------- | -------- |
   | `/yoke:<name>` | <one-line description> | <Output> |
   ```

   The one-line description is the first sentence of the SKILL.md
   description (everything up to the first `. `). The Output column is the
   value from `docs/<name>.md`'s `**Output:**` line when present, else `—`.

7. Render the CLAUDE.md block to `.yoke/sync-docs-tmp/claudemd-block.md` as
   a bullet list matching the current style at `CLAUDE.md:62-78`:

   ```markdown
   - `/<name>` — <one-line description>
   ```

## Phase 4 — Sentinel check

For each of `README.md` and `CLAUDE.md`, count line-anchored occurrences of each marker:

```bash
grep -cE "^<!-- yoke:skills:start -->\$" README.md   # must be 1
grep -cE "^<!-- yoke:skills:end -->\$"   README.md   # must be 1
```

Anchor to line boundaries — the catalog table itself may mention the marker text inside cells (the sync-docs row literally describes the markers). Only standalone-line occurrences count as sentinels.

The standalone start marker line must come before the standalone end marker line.

On any failure:

```
Markers missing or unbalanced in <file>.
Add exactly one <!-- yoke:skills:start --> and one <!-- yoke:skills:end -->
around the catalog block; re-run.
```

In `--check` mode → exit non-green. In write mode → abort before any write.

## Phase 5 — Write or diff

### Write mode

For each per-skill MDX in `.yoke/sync-docs-tmp/skills/`:

```bash
cp .yoke/sync-docs-tmp/skills/*.mdx site/src/content/docs/skills/
```

For `README.md`: replace the byte range between the two sentinels with the
contents of `.yoke/sync-docs-tmp/readme-block.md`, surrounded by a single
blank line on each side. Leave every other byte unchanged.

For `CLAUDE.md`: same procedure with `.yoke/sync-docs-tmp/claudemd-block.md`.

Then normalize the output through prettier so the round-trip matches what husky's lint-staged hook would produce on commit:

```bash
pnpm exec prettier --write \
  README.md CLAUDE.md \
  site/src/content/docs/skills/*.mdx
```

Send the completion notification:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh \
  --type STAGE_COMPLETE \
  --skill sync-docs \
  --phase Write \
  --slug sync-docs \
  --title "Docs synced" \
  --body "<N> MDX pages written; README + CLAUDE.md catalog blocks regenerated"
```

### Check mode

Normalize the rendered tree through prettier first (so the comparison is fair against the prettier-formatted live tree):

```bash
pnpm exec prettier --write \
  .yoke/sync-docs-tmp/skills/*.mdx \
  .yoke/sync-docs-tmp/readme-block.md \
  .yoke/sync-docs-tmp/claudemd-block.md
```

Then compare the tmp tree against the live tree:

```bash
diff -r .yoke/sync-docs-tmp/skills/ site/src/content/docs/skills/
```

Extract the byte range between sentinels from `README.md` and `CLAUDE.md`;
compare against the rendered blocks. List every file with drift.

On any drift:

```
Docs drift detected in: <files, newline-separated>
Run `/yoke:sync-docs` to regenerate, review the diff, commit, and retry.
```

Exit non-green.

When the live tree matches the tmp tree byte-for-byte → exit zero.

## Rules

- Catalog membership: 17 shipped skills under `skills/` + `sync-docs` itself.
  Never include `.claude/skills/*` skills (`yoke-create`, `yoke-release`,
  `yoke-validate`).
- Sentinels are required. Refuse to write when they are missing or
  unbalanced. Never auto-insert.
- Touch only the bytes between the sentinels in `README.md` and `CLAUDE.md`.
  Every other byte must round-trip unchanged.
- The raw SKILL.md inside `<details>` is the source of truth — never edit
  it during render.
- Idempotence: running `/yoke:sync-docs` then `/yoke:sync-docs --check`
  must produce no diff. If the check call reports drift after a fresh write,
  the renderer is non-deterministic — fix the renderer before relying on
  the release gate.
- Render artifacts live in `.yoke/sync-docs-tmp/` (gitignored). Never commit
  them.

## Reference

- `reference/mdx-template.md` — the 7-section per-skill MDX template.
- `reference/sync-spec.md` — sentinel rules, enumeration rules, check-mode
  contract, idempotence rule.

## Example

```
/yoke:sync-docs
```

→ Writes `site/src/content/docs/skills/<name>.mdx` for all 18 skills,
regenerates the README and CLAUDE.md catalog blocks.

```
/yoke:sync-docs --check
```

→ Exits zero when everything is in sync; exits non-green and lists the
affected files on any drift.

## Connections

```
/yoke-create  → /yoke:sync-docs  (Phase 6c tail; regenerates catalog for the new skill)
/yoke-release → /yoke:sync-docs --check  (Phase 0f gate; halts release on drift)
```
