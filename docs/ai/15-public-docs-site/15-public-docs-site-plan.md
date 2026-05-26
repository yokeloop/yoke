# Public docs site — implementation plan

**Task:** [docs/ai/15-public-docs-site/15-public-docs-site-task.md](./15-public-docs-site-task.md)
**Complexity:** complex
**Mode:** sub-agents
**Parallel:** true

## Pre-flight correction

The task file says `README.md:48-70` holds an "already-installed sentinel
block". `grep -n "yoke:skills" README.md` returns zero hits — the block does
not exist. README's current `## Skills` section runs from line 48 to line
~221 as hand-formatted prose with `### /<name>` headings, not a table. This
plan adds sentinels to **both** `README.md` and `CLAUDE.md` by hand in T05,
and `/yoke:sync-docs` (T06) converts the wrapped region into a compact
3-column table on first run (T11).

## Design decisions

### DD-1: pnpm workspace with `site/` as the only package

**Decision:** Add `pnpm-workspace.yaml` with `packages: ['site']`. Site keeps
its own `package.json` and dependency tree.
**Rationale:** Root `package.json:18-30` already runs pnpm + husky + prettier
across `**/*.{md,json}`; PRD verification uses `pnpm --filter site build`,
which only works with a workspace. Isolation prevents Astro deps from
hoisting into the root tree the hooks scan.
**Alternative:** Mono root `package.json` with Astro deps — mixes plugin
runtime with build, and pollutes lint-staged.

### DD-2: Sync-docs is a single-file orchestrator, not a sub-agent fan-out

**Decision:** `skills/sync-docs/SKILL.md` runs inline with two helper
reference files (`reference/mdx-template.md`, `reference/sync-spec.md`).
No sub-agents.
**Rationale:** Sync is deterministic enumeration → render → write/diff. 17
shipped skills × 5 fields fits one context window. The closest existing
pattern — yoke-release Phase 1 Agent 3 (`:164-192`) — is being deleted by
this task precisely because fan-out wasn't earning its keep. Adding agents
under sync-docs would nest three deep when `/yoke-release` or `/yoke-create`
invokes it.
**Alternative:** Per-skill sub-agent fan-out — overkill; serializes nothing
meaningful and triples context.

### DD-3: `--check` mode reuses the write pipeline plus `git diff`

**Decision:** One render pipeline writes to `.yoke/sync-docs-tmp/`. Write
mode copies the tmp tree over the live tree. Check mode runs
`diff -r .yoke/sync-docs-tmp/skills/ site/src/content/docs/skills/` and
compares the rendered README + CLAUDE.md sentinel ranges against the live
files; exits non-green on any drift and names the affected files.
**Rationale:** Single source of truth for "what we'd write". Eliminates
write-vs-check divergence. Matches the atomic `tmp + mv` pattern already in
`lib/notify.sh:67`.
**Alternative:** In-memory string compare — loses line-level diff output for
the error message.

### DD-4: Sentinels are required; sync refuses to write when they are absent

**Decision:** For each target file, sync reads the file, locates exactly one
`<!-- yoke:skills:start -->` and one `<!-- yoke:skills:end -->`, replaces
only the byte range between them, and leaves every other byte intact. Any
deviation (missing marker, unbalanced count, start after end) aborts with a
filename in the error. Sentinels land in T05 by hand — never auto-inserted.
**Rationale:** Task constraints "touch only the four surfaces sync-docs
owns" and "never auto-insert". Marker-safety verification depends on a hard
refusal.
**Alternative:** Auto-insert missing markers — risks wrapping the wrong
region when a heading later changes.

### DD-5: Per-skill summary prefers `docs/<name>.md`; SKILL.md is the fallback

**Decision:** For each skill: read `skills/<name>/SKILL.md` frontmatter for
`name` + `description`; parse trigger phrases (quoted strings in
description); if `docs/<name>.md` exists, embed its `## Input` / `## Output`
/ example section into the MDX summary; otherwise extract the equivalent
from the SKILL.md body. The raw SKILL.md always lives inside the
`<details>` block regardless of source. Footer: `View source on GitHub`
linking to `https://github.com/yokeloop/yoke/blob/main/skills/<name>/SKILL.md`.
**Rationale:** Requirement 7. Every shipped skill has a `docs/<name>.md`
today; honour the hand-written prose where it exists.
**Alternative:** Astro glob-import — ADR 0002 rejected (LLM-instruction
tone leaks into the public page).

### DD-6: Sidebar groups encoded in `astro.config.mjs`

**Decision:** Five groups, hand-mapped:

- **Dev loop** — task, plan, do, fix, review
- **Git** — gca, gp, pr, gst
- **Analysis** — explore, grill, grill-docs
- **Meta** — prd, issues, handoff, bootstrap, help
- **Plugin dev** — sync-docs

`yoke-create` and `yoke-release` stay invisible (local-only).
**Rationale:** Sidebar is a public taxonomy — keep it human-curated in one
file. `/gst` is git status by description (`README.md` describes it as
"branch, changes, diff"); fits Git. Plugin dev group has one item today
(sync-docs) so future shipped plugin-dev tools land cleanly.
**Alternative:** Derive groups from a SKILL.md field — no such field
exists; introducing one is scope creep.

### DD-7: Pages-from-Actions, no `gh-pages` branch

**Decision:** Workflow uses `actions/upload-pages-artifact` +
`actions/deploy-pages`. Two jobs (`build` then `deploy`). Permissions:
`contents: read`, `pages: write`, `id-token: write`. Deploy environment
`github-pages`. Triggers: `push` to `main` (paths filter
`site/**`, `skills/**`, `docs/**`, `CLAUDE.md`, `README.md`,
`.github/workflows/docs.yml`) + `workflow_dispatch`.
**Rationale:** Constraint explicit. Supersedes ADR 0001's `gh-pages` branch
wording — PR description must flag this.
**Alternative:** `peaceiris/actions-gh-pages` — creates the forbidden
branch.

### DD-8: Idempotence proved by round-tripping check after write

**Decision:** Verification calls `/yoke:sync-docs` then
`/yoke:sync-docs --check`; the second call must exit zero with `git diff
--stat` showing no changes between calls.
**Rationale:** PRD lines 177-180. Without unit tests, round-trip is the
deterministic signal.
**Alternative:** Snapshot tests — PRD rejected (lines 200-203).

### DD-9: `/yoke-release` Phase 0 gains `0f. Docs drift gate`; Phase 1 Agent 3 dies

**Decision:** Insert `### 0f. Docs drift gate` between line 98 ("Exit.") and
line 100 ("TodoWrite: mark `Preflight` as done."). Body runs
`/yoke:sync-docs --check`; on non-zero exit, the release halts with
`Docs drift detected in <files>. Run /yoke:sync-docs, review, commit, then
retry.` Delete lines 164-192 (Phase 1 Agent 3 entirely). Update line 106
`Run 4 agents in parallel` → `Run 3 agents in parallel`. Leave the
"Agent 4" heading in place — no renumbering.
**Rationale:** Requirement 9. Old Agent 3 scanned the no-longer-existing
`### /<name>` heading shape; the check gate replaces it.
**Alternative:** Keep Agent 3 as belt-and-braces — user rejected; would
trip on every release.

### DD-10: `/yoke-create` Phase 6 — sync runs before format

**Decision:** Phase 6 becomes `6a. Documentation` → `6b. Sync docs`
(`/yoke:sync-docs`) → `6c. Format` (`pnpm run format`). Delete the current
6b (lines 365-382, README hand-edit) and 6c (lines 383-392, CLAUDE.md
hand-edit); rename the current `6d. Format` to `6c. Format`.
**Rationale:** Sync writes the freshly-generated MDX plus byte ranges in
README + CLAUDE.md. Running format afterwards normalizes all of it in one
pass regardless of whether sync's output is perfectly prettier-clean. This
overrides the task wording "single sync invocation after format" — user
chose sync-first explicitly.
**Alternative:** Sync after format — requires sync to emit prettier-clean
output by construction; user rejected.

## Tasks

### Task 1: Workspace scaffold + ignores

- **Files:** `pnpm-workspace.yaml` (create), `.gitignore` (edit, append 3
  lines), `.prettierignore` (edit, append 3 lines)
- **Depends on:** none
- **Scope:** S
- **What:** Create the pnpm workspace and exclude site build artifacts from
  git and prettier.
- **How:**
  - `pnpm-workspace.yaml`: `packages:\n  - 'site'\n`.
  - Append `site/dist/`, `site/node_modules/`, `site/.astro/` to both
    `.gitignore` and `.prettierignore`.
- **Context:** `.gitignore`, `.prettierignore`, `package.json:18-30`.
- **Verify:** `test -f pnpm-workspace.yaml && grep -c "site/" .gitignore .prettierignore` — each path returns ≥ 3.

### Task 2: Site package.json (Starlight starter)

- **Files:** `site/package.json` (create)
- **Depends on:** T01
- **Scope:** S
- **What:** Add the Astro Starlight starter package manifest with `dev`,
  `build`, `preview` scripts.
- **How:** `name: "site"`, `private: true`, `type: "module"`. Scripts:
  `astro dev`, `astro build`, `astro preview`. Deps: `astro@^4`,
  `@astrojs/starlight@^0.30`. No format script — root prettier owns
  `**/*.{md,json}`.
- **Context:** CLAUDE.md "Testing locally", `package.json` root scripts.
- **Verify:** `pnpm install` from repo root exits 0; `ls site/node_modules/@astrojs/starlight` exists.

### Task 3: Astro config (site + base + sidebar + Pagefind)

- **Files:** `site/astro.config.mjs` (create)
- **Depends on:** T02
- **Scope:** S
- **What:** Astro config with the public URL, base path, Starlight
  integration, sidebar groups per DD-6, and the GitHub social link.
- **How:**
  - `site: 'https://yokeloop.github.io'`, `base: '/yoke'`.
  - `integrations: [starlight({ title: 'yoke', social: { github: 'https://github.com/yokeloop/yoke' }, sidebar: [...] })]`.
  - Sidebar items: 3 flat top-level (`what-is-yoke`, `install`,
    `concepts`) followed by the 5 groups from DD-6, each group `{ label,
    items: [{ label: '/yoke:<name>', slug: 'skills/<name>' }, ...] }`.
  - Comment confirming Pagefind is on by default in Starlight.
- **Context:** DD-6 mapping, requirement 2.
- **Verify:** `pnpm --filter site build` exits 0 (passes once T04 provides
  the referenced pages).

### Task 4: Landing + 3 top-level pages + skills/.gitkeep

- **Files:** `site/src/content/docs/index.mdx`,
  `site/src/content/docs/what-is-yoke.mdx`,
  `site/src/content/docs/install.mdx`,
  `site/src/content/docs/concepts.mdx`,
  `site/src/content/docs/skills/.gitkeep` (all create)
- **Depends on:** T03
- **Scope:** M
- **What:** Hand-written splash landing and three explainer pages. Tone
  matches `skills/help/SKILL.md`. `skills/` directory holds the placeholder
  until T11 generates per-skill MDX.
- **How:**
  - `index.mdx`: Starlight `template: splash`. Hero `title: "yoke"`,
    `tagline: "Skills and slash-commands for Claude Code that ship a
    full dev loop."`, `actions:` `[{text: 'Install', link: '/install/',
    variant: 'primary', icon: 'download'}, {text: 'Browse skills', link:
    '/skills/task/', variant: 'secondary'}]`. Body: `<CardGrid>` with 5
    `<Card>`s, one per workflow stage (titles: Dev loop, Git, Analysis,
    Meta, Plugin dev; each links to its first skill).
  - `what-is-yoke.mdx`: 2-3 paragraphs derived from `README.md:1-46`.
  - `install.mdx`: marketplace install snippet + local dev block from
    `README.md` install section.
  - `concepts.mdx`: skills / commands / agents distinction, mirroring
    `CLAUDE.md:16-23`.
  - `skills/.gitkeep`: empty.
- **Context:** `README.md:1-46`, `CLAUDE.md:16-23`, `skills/help/SKILL.md`
  (tone).
- **Verify:** `pnpm --filter site build` exits 0; `site/dist/index.html`
  exists; opening it shows the hero text "yoke".

### Task 5: Add sentinels by hand to README.md and CLAUDE.md

- **Files:** `README.md` (edit), `CLAUDE.md` (edit)
- **Depends on:** none
- **Scope:** S
- **What:** Insert `<!-- yoke:skills:start -->` and
  `<!-- yoke:skills:end -->` around each catalog block. Do not touch any
  existing prose inside the markers — sync-docs rewrites the content
  later.
- **How:**
  - `README.md`: open with the marker immediately after `## Skills`
    (between line 48 and the first `### /task` heading); close with the
    marker immediately before `## Local skills (development)`. Every
    `### /<name>` entry from `/task` through `/help` sits inside.
  - `CLAUDE.md`: open with the marker on the line after
    `## Implemented skills` (line 60); close before
    `## Local skills (development)` (line 80). The 17 bullets at lines
    62-78 sit inside.
- **Context:** `README.md:48-247`, `CLAUDE.md:60-80`, DD-4.
- **Verify:** `grep -c "yoke:skills" README.md CLAUDE.md` returns 2 for
  each file.

### Task 6: Create the sync-docs skill (orchestrator + 2 reference files)

- **Files:** `skills/sync-docs/SKILL.md` (create),
  `skills/sync-docs/reference/mdx-template.md` (create),
  `skills/sync-docs/reference/sync-spec.md` (create)
- **Depends on:** none
- **Scope:** L
- **What:** Shipped skill that regenerates the public catalog. Two modes:
  write (default) and check (`--check`). Refuses on missing/unbalanced
  sentinels.
- **How:**
  - **Frontmatter:** `name: sync-docs`; description names the trigger
    phrases ("sync docs", "regenerate docs", "update the skill catalog",
    "--check") and states the refusal contract.
  - **Pipeline (5 phases, TodoWrite block mirroring
    `.claude/skills/yoke-create/SKILL.md:27-40`):**
    1. **Preflight** — verify `.claude-plugin/plugin.json` exists and
       `skills/` is a directory; parse `--check` from `$ARGUMENTS`.
    2. **Enumerate** — `ls skills/` → the 17 shipped skills plus
       `sync-docs`. Never include anything under `.claude/skills/`.
    3. **Render** — for each skill: read `skills/<name>/SKILL.md`, parse
       frontmatter `name`/`description`, extract trigger phrases (quoted
       strings in the description), read `docs/<name>.md` if present;
       write `.yoke/sync-docs-tmp/skills/<name>.mdx` per
       `reference/mdx-template.md`. Render the README block as a
       3-column table (`/yoke:<name>` | one-line description | output)
       and the CLAUDE.md block as a bullet list matching the current
       style at `CLAUDE.md:62-78`.
    4. **Sentinel check** — for `README.md` and `CLAUDE.md`: confirm
       exactly one start and one end marker, start before end. Any
       failure → halt and name the file; in `--check` mode exit
       non-green; in write mode abort.
    5. **Write or diff** —
       - Write mode: copy `.yoke/sync-docs-tmp/skills/*.mdx` to
         `site/src/content/docs/skills/`; replace the byte range between
         markers in README and CLAUDE.md;
         `bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE
         --skill sync-docs --phase Write --slug sync-docs --title
         "Docs synced" --body "<count> files written"`.
       - Check mode: `diff -r .yoke/sync-docs-tmp/skills/
         site/src/content/docs/skills/`; compare rendered README and
         CLAUDE.md blocks against the live byte ranges; exit non-green
         and list affected files on any drift; exit zero otherwise.
  - **`reference/mdx-template.md`** — the 7-section MDX template (title,
    one-line, triggers, Use it, inputs/outputs, `<details>` raw SKILL.md,
    footer link).
  - **`reference/sync-spec.md`** — sentinel rules (DD-4), enumeration
    rule ("17 skills under `skills/` + sync-docs itself; never include
    `.claude/skills/*`"), check-mode contract (DD-3), idempotence rule
    (DD-8).
- **Context:** `.claude/skills/yoke-release/SKILL.md:164-192`
  (enumeration pattern, about to be deleted),
  `.claude/skills/yoke-create/SKILL.md:1-60` (phase/TodoWrite template),
  `lib/notify.sh:13-23` (CLI contract), `skills/plan/SKILL.md:1-7`
  (frontmatter shape), DD-2, DD-3, DD-4, DD-5.
- **Verify:** `head -1 skills/sync-docs/SKILL.md` returns `---`;
  `test -f skills/sync-docs/reference/mdx-template.md && test -f
  skills/sync-docs/reference/sync-spec.md`.

### Task 7: Wire `/yoke-release` Phase 0 check gate and delete Agent 3

- **Files:** `.claude/skills/yoke-release/SKILL.md` (edit)
- **Depends on:** T06
- **Scope:** S
- **What:** Add the drift gate at the end of Phase 0 and remove the
  redundant Phase 1 Agent 3.
- **How:**
  - Insert at line 99 (between line 98 `Exit.` and line 100 `TodoWrite:
    mark "Preflight" as done.`):

    ```
    ### 0f. Docs drift gate

    Run `/yoke:sync-docs --check`.

    On non-green exit → report: "Docs drift detected in <files named by
    sync-docs>. Run `/yoke:sync-docs`, review the diff, commit, and
    retry the release." Halt.
    ```

  - Delete lines 164-192 (`### Agent 3` heading through the end of its
    prompt block).
  - Update line 106 `Run 4 agents in parallel` → `Run 3 agents in
    parallel`.
- **Context:** `.claude/skills/yoke-release/SKILL.md:98-194`, DD-9.
- **Verify:** `grep -n "0f. Docs drift gate" .claude/skills/yoke-release/SKILL.md` returns 1 hit; `grep -c "### Agent 3" .claude/skills/yoke-release/SKILL.md` returns 0; `grep -n "3 agents in parallel" .claude/skills/yoke-release/SKILL.md` returns 1 hit.

### Task 8: Collapse `/yoke-create` Phase 6 to sync-then-format

- **Files:** `.claude/skills/yoke-create/SKILL.md` (edit)
- **Depends on:** T06
- **Scope:** S
- **What:** Replace the stale Phase 6b (README hand-edit) and 6c (CLAUDE.md
  hand-edit) with a single sync invocation that runs before format.
- **How:**
  - Delete lines 365-392 (`### 6b. README.md` block through `### 6c.
    CLAUDE.md` block).
  - Insert new `### 6b. Sync docs`:

    ```
    ### 6b. Sync docs

    Run `/yoke:sync-docs` to regenerate the per-skill MDX page, the
    README catalog block, and the CLAUDE.md block.

    On failure → name the file sync-docs reports and halt.
    ```

  - Rename the current `### 6d. Format` to `### 6c. Format`.
- **Context:** `.claude/skills/yoke-create/SKILL.md:321-403`, DD-10.
- **Verify:** `grep -c "### 6b. README.md\|### 6c. CLAUDE.md" .claude/skills/yoke-create/SKILL.md` returns 0; `grep -n "### 6b. Sync docs" .claude/skills/yoke-create/SKILL.md` returns 1 hit; `grep -n "### 6c. Format" .claude/skills/yoke-create/SKILL.md` returns 1 hit.

### Task 9: GitHub Actions workflow (Pages-from-Actions)

- **Files:** `.github/workflows/docs.yml` (create)
- **Depends on:** T03
- **Scope:** M
- **What:** Build the site on push to `main` and deploy via
  `actions/deploy-pages` — no `gh-pages` branch.
- **How:**
  - `name: docs`
  - `on:` `push.branches: [main]` with paths filter for `site/**`,
    `skills/**`, `docs/**`, `README.md`, `CLAUDE.md`,
    `.github/workflows/docs.yml`; plus `workflow_dispatch: {}`.
  - `permissions:` `contents: read`, `pages: write`, `id-token: write`.
  - `concurrency:` `group: pages`, `cancel-in-progress: false`.
  - Job `build` (ubuntu-latest): `actions/checkout@v4` →
    `pnpm/action-setup@v4` (version 9) → `actions/setup-node@v4` (node
    20, cache pnpm) → `pnpm install` → `pnpm --filter site build` →
    `actions/configure-pages@v5` → `actions/upload-pages-artifact@v3`
    with `path: site/dist`.
  - Job `deploy` (needs `build`): `environment:` `name: github-pages`,
    `url: ${{ steps.deployment.outputs.page_url }}`;
    `actions/deploy-pages@v4` as `id: deployment`.
  - Header comment: "One-time setup: Settings → Pages → Source =
    GitHub Actions. Supersedes ADR 0001's `gh-pages` branch wording —
    see PR notes."
- **Context:** Constraints "Pages-from-Actions, not `gh-pages` branch" and
  "Job permissions: `pages: write, id-token: write`", DD-7,
  requirement 10.
- **Verify:** `grep -c "actions/deploy-pages" .github/workflows/docs.yml` returns ≥ 1; `grep -c "pages: write" .github/workflows/docs.yml` returns 1; `grep -c "id-token: write" .github/workflows/docs.yml` returns 1; `grep -c "gh-pages" .github/workflows/docs.yml` returns 0.

### Task 10: Per-skill long-form doc for sync-docs

- **Files:** `docs/sync-docs.md` (create)
- **Depends on:** T06
- **Scope:** S
- **What:** Add `docs/sync-docs.md` so sync-docs has the same per-skill
  long-form doc every shipped skill carries today (input, phases, output,
  example).
- **How:** Follow the template in `docs/plan.md` — sections `## Input`,
  `## Phases`, `## Output`, `## Example`. Include a `--check` example.
- **Context:** `docs/plan.md:1-50`, CLAUDE.md "Conventions" list.
- **Verify:** `test -f docs/sync-docs.md && head -1 docs/sync-docs.md` returns a line beginning with `# `.

### Task 11: First regeneration — run `/yoke:sync-docs`

- **Files:** `site/src/content/docs/skills/*.mdx` (18 files, create),
  `README.md` (edit, between sentinels), `CLAUDE.md` (edit, between
  sentinels)
- **Depends on:** T04, T05, T06, T10
- **Scope:** M
- **What:** First invocation of the new skill. Generates the 18 per-skill
  MDX pages and rewrites the marker blocks in README + CLAUDE.md.
- **How:** Invoke `/yoke:sync-docs` (write mode). Confirm the 18 files
  appear. Run `pnpm run format` to normalize the generated MDX. Run
  `/yoke:sync-docs --check` immediately afterwards — must exit zero with
  no diff.
- **Context:** DD-5 template, requirement 5, requirement 6.
- **Verify:** `ls site/src/content/docs/skills/*.mdx | wc -l` returns 18; `grep -A1 "yoke:skills:start" README.md | head -5` shows the 3-column table; `grep -A1 "yoke:skills:start" CLAUDE.md | head -5` shows the bullet list; the second `/yoke:sync-docs --check` exits zero.

### Task 12: Validation

- **Files:** —
- **Depends on:** all
- **Scope:** S
- **What:** Run the full verification matrix.
- **Context:** —
- **Verify:**
  - `pnpm install` (repo root) — exits 0.
  - `pnpm --filter site build` — exits 0; `site/dist/index.html` and
    `site/dist/skills/plan/index.html` exist.
  - `pnpm --filter site preview &` then
    `curl -s -o /dev/null -w "%{http_code}" http://localhost:4321/yoke/`
    returns `200`; kill the process.
  - `/yoke:sync-docs && /yoke:sync-docs --check` — second exits zero;
    `git diff --stat` between the two calls is empty.
  - Hand-edit one row of the README table inside the sentinels →
    `/yoke:sync-docs --check` exits non-zero and names `README.md`;
    revert.
  - Remove the closing sentinel from `CLAUDE.md` → `/yoke:sync-docs`
    (write) refuses and names `CLAUDE.md`; revert.
  - `pnpm run format:check` — exits 0.
  - `git ls-remote --heads origin gh-pages` — empty.
  - `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json'))"` — no exception.
  - `head -1 skills/*/SKILL.md` — every line is `---`.
  - `grep -c "yoke:skills" README.md CLAUDE.md` — each returns 2.

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** 12 atomic tasks across 5 disjoint surfaces with 4 parallel
  groups and zero cross-layer coordination — fits the sub-agents row of
  the routing matrix.
- **Order:**

  ```
  Group A (parallel):    T01, T05, T06
    ─── barrier ───
  Group B (parallel):    T02 (deps T01), T07 (deps T06),
                         T08 (deps T06), T10 (deps T06)
    ─── barrier ───
  Group C (sequential):  T03 (deps T02)
    ─── barrier ───
  Group D (parallel):    T04 (deps T03), T09 (deps T03)
    ─── barrier ───
  Group E (sequential):  T11 (deps T04, T05, T06, T10)
    ─── barrier ───
  Group F (sequential):  T12 (deps all)
  ```

  Critical path: T01 → T02 → T03 → T04 → T11 → T12 (6 hops).

## Verification

- `pnpm install` from the repo root → resolves the new `site/` workspace
  without errors.
- `pnpm --filter site build` → exits 0; produces `site/dist/index.html`
  and `site/dist/skills/<name>/index.html` for every shipped skill.
- `pnpm --filter site dev` → serves at `http://localhost:4321/yoke/`;
  landing page loads with the hero, both CTAs, and the workflow-stage
  feature cards.
- Run `/yoke:sync-docs` twice in a row; the second run produces an empty
  diff (`git diff --stat` shows zero changes) — round-trip idempotence.
- Hand-edit one row of the table in `README.md` between the sentinels,
  then run `/yoke:sync-docs --check` → exits non-green and names
  `README.md` — drift detection.
- Remove the closing sentinel from `CLAUDE.md` and run `/yoke:sync-docs`
  (write mode) → refuses to write, names `CLAUDE.md` — marker safety.
- Run `/yoke-release` against a clean main; the release proceeds past
  Phase 0. Hand-edit the README table to introduce drift, run
  `/yoke-release` again → halts at the `0f. Docs drift gate` step with a
  pointer to `README.md`.
- Run `/yoke-create` end-to-end for a throwaway skill; on completion,
  `README.md` and `CLAUDE.md` contain the new entry inside the sentinels
  and `site/src/content/docs/skills/<name>.mdx` exists. The previous
  Phase 6b/6c hand-edits leave no residue.
- Push to `main`; the `docs.yml` workflow runs to success; visiting
  `https://yokeloop.github.io/yoke` shows the sidebar grouped by
  workflow stage, the Pagefind search box, and at least the
  `/yoke:plan` page rendered with all seven sections.
- `git ls-remote --heads origin gh-pages` returns empty — Pages-from-
  Actions does not create a `gh-pages` branch.
- `pnpm run format:check` exits 0 after the change.

## Materials

- [PRD #15 — Public docs site](https://github.com/yokeloop/yoke/issues/15)
- `docs/ai/public-docs-site/public-docs-site-prd.md`
- `docs/adr/0001-docs-site-on-astro-starlight.md`
- `docs/adr/0002-sync-docs-skill.md`
- `README.md:48-247` (current `## Skills` prose block; sentinels added in
  T05; converted to table in T11)
- `CLAUDE.md:60-80` (`## Implemented skills` block; sentinels added in
  T05)
- `.claude/skills/yoke-release/SKILL.md:98-194` (Phase 0 tail and Phase 1
  Agent 3 region to amend)
- `.claude/skills/yoke-create/SKILL.md:321-403` (Phase 6/7 region to
  amend)
- `skills/help/SKILL.md` (catalog prose tone)
- `lib/notify.sh` (Phase Complete notification contract)
- `skills/gca/reference/commit-convention.md` (commit format)
- [Starlight docs](https://starlight.astro.build/) (framework reference)
- [`actions/deploy-pages`](https://github.com/actions/deploy-pages)
- [Pagefind](https://pagefind.app/) (Starlight default search)
