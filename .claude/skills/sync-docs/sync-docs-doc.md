# Skill /sync-docs

Regenerates the public skill catalog from `skills/*/SKILL.md`. One run rebuilds three surfaces: per-skill MDX pages under `site/src/content/docs/skills/`, the catalog table between sentinel markers in `README.md`, and the bullet list between the same markers in `CLAUDE.md`. `--check` mode detects drift without writing.

## Input

`$ARGUMENTS` — empty for write mode (default), or `--check` for drift detection.

```
/sync-docs
/sync-docs --check
```

## Phases

The skill runs through 5 sequential phases. No user interaction.

| Phase | Name               | What happens                                                                                     |
| ----- | ------------------ | ------------------------------------------------------------------------------------------------ |
| 1     | **Preflight**      | Verify the repo and parse `--check`                                                              |
| 2     | **Enumerate**      | List every directory under `skills/` (13 today); never `.claude/skills/*` |
| 3     | **Render**         | Write per-skill MDX, README block, CLAUDE.md block into `.yoke/sync-docs-tmp/`                   |
| 4     | **Sentinel check** | Verify one start + one end marker in each of `README.md` and `CLAUDE.md`                         |
| 5     | **Write or diff**  | Write mode copies tmp tree over live; check mode diffs and exits non-green on drift              |

## Output

**Write mode** writes:

- `site/src/content/docs/skills/<name>.mdx` — one MDX page per skill (13 today).
- The byte range between `<!-- yoke:skills:start -->` and `<!-- yoke:skills:end -->` in `README.md` (a 3-column table).
- The byte range between the same markers in `CLAUDE.md` (a bullet list).

**Check mode** writes nothing. On drift it lists affected files and exits non-green.

## Sub-agents

None. The skill runs inline as a single orchestrator.

## Example

Write the catalog after adding or editing a skill:

```
/sync-docs
```

Check for drift before a release:

```
/sync-docs --check
```

## Reference

- `.claude/skills/sync-docs/reference/mdx-template.md` — the 7-section per-skill MDX template.
- `.claude/skills/sync-docs/reference/sync-spec.md` — sentinel rules, enumeration rules, check-mode contract, idempotence rule.

## Connections

```
/yoke-create  → /sync-docs           (Phase 6b tail; refreshes the catalog for the new skill)
/yoke-release → /sync-docs --check   (Phase 0f gate; halts release on drift)
```

`/yoke-create` invokes sync as the second-to-last step of Phase 6, before format. `/yoke-release` invokes `--check` as the last step of Phase 0; a non-green exit halts the release until the author runs sync, reviews the diff, and commits.
