# Bootstrap pipeline — mechanics

The full phase pipeline behind `/yoke:bootstrap`. The SKILL.md routes here; this
file holds every agent dispatch, the PROJECT_PROFILE shape, verification
handling, the `.yoke/flow.md` generation, and the commit steps.

## Agents

Delegate each phase to an agent via the Agent tool:

| Phase        | Agent                               | Model  |
| ------------ | ----------------------------------- | ------ |
| Stack        | `agents/stack-detector.md`          | haiku  |
| Architecture | `agents/architecture-mapper.md`     | sonnet |
| Conventions  | `agents/convention-scanner.md`      | sonnet |
| Validation   | `agents/validation-scanner.md`      | haiku  |
| Rules        | `agents/existing-rules-detector.md` | haiku  |
| Domain       | `agents/domain-analyzer.md`         | sonnet |
| CLAUDE.md    | `agents/claude-md-generator.md`     | sonnet |
| yoke-context | `agents/yoke-context-generator.md`  | haiku  |
| Automation   | `agents/automation-recommender.md`  | haiku  |
| Verification | `agents/bootstrap-verifier.md`      | sonnet |

Agents perform all investigation and file generation. The orchestrator
sequences them, writes `.yoke/flow.md`, and runs git. Mark each phase in
TodoWrite the moment it completes. When dispatching an agent, replace
`{{PLACEHOLDER}}` in the prompt with real values from findings — agents receive
data, not template variables. Run commands with long output through
`2>&1 | tail -20`.

## Pipeline

8 phases.

```text
0. Preflight  → verify git-repo, not a yoke-repo
1. Detect     → 6 parallel agents investigate the project
2. Synthesize → aggregate PROJECT_PROFILE
3. Generate   → CLAUDE.md + .yoke/yoke-context.md + .yoke/ skeleton + recommendations
4. Verify     → check files and quality
5. Flow map   → ask repos/finish/tracker + committed-vs-local-only, write .yoke/flow.md
6. Confirm    → show the result, AskUserQuestion
7. Commit     → commit the artifacts (respecting local-only)
```

---

## Phase 0 — Preflight

Check two conditions before starting.

### 0a. Git repository

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

Result false or error → tell the user: "/bootstrap only runs inside a git project." Exit.

### 0b. Not a yoke-repo

```bash
test -f .claude-plugin/plugin.json && echo "YOKE_REPO" || echo "OK"
```

YOKE_REPO → tell the user: "/bootstrap runs in target projects, not for yoke plugins." Exit.

Both conditions passed → transition to Phase 1. Mark in TodoWrite: `[x] Preflight`.

---

## Phase 1 — Detect

Dispatch 6 agents **in parallel** via the Agent tool (6 calls at once):

1. **stack-detector** — read `agents/stack-detector.md`, pass the prompt to the agent.
   Result → STACK_FINDINGS:

   ```text
   LANGUAGES, FRAMEWORKS, PACKAGE_MANAGER, RUNTIME, RUNTIME_VERSION
   ```

2. **architecture-mapper** — read `agents/architecture-mapper.md`, pass the prompt to the agent.
   Result → ARCH_FINDINGS:

   ```text
   PATTERN, LAYERS, ENTRY_POINTS, KEY_DIRS
   ```

3. **convention-scanner** — read `agents/convention-scanner.md`, pass the prompt to the agent.
   Result → CONV_FINDINGS:

   ```text
   NAMING, FILE_NAMING, IMPORT_STYLE, TEST_CONVENTIONS
   ```

4. **validation-scanner** — read `agents/validation-scanner.md`, pass the prompt to the agent.
   Result → VAL_FINDINGS:

   ```text
   DEV, BUILD, TEST, LINT, FORMAT, TYPECHECK
   ```

5. **existing-rules-detector** — read `agents/existing-rules-detector.md`, pass the prompt to the agent.
   Result → RULES_FINDINGS:

   ```text
   CLAUDE_MD_EXISTS, CLAUDE_MD_QUALITY, CLAUDE_MD_CONTENT, OTHER_RULES, DOC_CONTENT
   ```

6. **domain-analyzer** — read `agents/domain-analyzer.md`, pass the prompt to the agent.
   Reads the domain model, API, abstractions, and environment variables.
   Result → DOMAIN_FINDINGS:

   ```text
   DOMAIN_MODELS, API_ENDPOINTS, KEY_ABSTRACTIONS, ENV_VARS, CODE_WORKAROUNDS
   ```

Wait for all 6. If an agent returns an error or empty result — record the issue
in VERIFY_NOTES and use empty values for that section.

Mark in TodoWrite: `[x] Detect`. Transition → Phase 2.

---

## Phase 2 — Synthesize

Aggregate the 6 findings into PROJECT_PROFILE:

```yaml
PROJECT_PROFILE:
  name: <from package.json/go.mod/Cargo.toml or directory name>
  languages: <from STACK_FINDINGS>
  frameworks: <from STACK_FINDINGS>
  package_manager: <from STACK_FINDINGS>
  runtime: <from STACK_FINDINGS>
  runtime_version: <from STACK_FINDINGS>

  architecture:
    pattern: <from ARCH_FINDINGS>
    layers: <from ARCH_FINDINGS>
    entry_points: <from ARCH_FINDINGS>
    key_dirs: <from ARCH_FINDINGS>

  commands:
    dev: <from VAL_FINDINGS>
    build: <from VAL_FINDINGS>
    test: <from VAL_FINDINGS>
    lint: <from VAL_FINDINGS>
    format: <from VAL_FINDINGS>
    typecheck: <from VAL_FINDINGS>

  conventions:
    naming: <from CONV_FINDINGS>
    file_naming: <from CONV_FINDINGS>
    import_style: <from CONV_FINDINGS>
    test_conventions: <from CONV_FINDINGS>

  existing_rules:
    claude_md_exists: <from RULES_FINDINGS>
    claude_md_quality: <from RULES_FINDINGS>
    claude_md_content: <from RULES_FINDINGS, if exists>
    other_rules: <from RULES_FINDINGS>
    doc_content: <from RULES_FINDINGS.DOC_CONTENT>

  domain:
    models: <from DOMAIN_FINDINGS>
    api_endpoints: <from DOMAIN_FINDINGS>
    key_abstractions: <from DOMAIN_FINDINGS>
    env_vars: <from DOMAIN_FINDINGS>
    code_workarounds: <from DOMAIN_FINDINGS>
```

If `$ARGUMENTS` is passed — add `user_description` to PROJECT_PROFILE.

Mark in TodoWrite: `[x] Synthesize`. Transition → Phase 3.

---

## Phase 3 — Generate

Dispatch 3 agents **in parallel** via the Agent tool:

1. **claude-md-generator** — read `agents/claude-md-generator.md`, pass to the agent:
   - the entire PROJECT_PROFILE
   - CLAUDE_MD_EXISTS from RULES_FINDINGS
   - CLAUDE_MD_CONTENT (if it exists)
   - DOC_CONTENT from PROJECT_PROFILE.existing_rules.doc_content
   - DOMAIN_FINDINGS from PROJECT_PROFILE.domain

   Result → CLAUDE_MD_STATUS:

   ```text
   STATUS: created|enriched
   SECTIONS_ADDED, SECTIONS_UPDATED, QUALITY_ESTIMATE
   ```

2. **yoke-context-generator** — read `agents/yoke-context-generator.md`, pass to the agent:
   - the entire PROJECT_PROFILE
   - DOC_CONTENT from PROJECT_PROFILE.existing_rules.doc_content
   - DOMAIN_FINDINGS from PROJECT_PROFILE.domain

   Result → YOKE_CONTEXT_FILE (path to `.yoke/yoke-context.md`) and YOKE_SKELETON
   (the scaffolded `.yoke/` layout). The agent writes `.yoke/yoke-context.md`
   (stack context) AND scaffolds the `.yoke/` skeleton: `.yoke/context.md`
   (domain glossary seeded from DOMAIN_FINDINGS), `.yoke/journal.md` (empty),
   `.yoke/ai/.gitkeep`, `.yoke/adr/.gitkeep`.

3. **automation-recommender** — read `agents/automation-recommender.md`, pass to the agent:
   - PROJECT_PROFILE (stack, frameworks, commands)

   Result → RECOMMENDATIONS (list of automation recommendations).

Wait for all 3. Mark in TodoWrite: `[x] Generate`. Transition → Phase 4.

---

## Phase 4 — Verify

Dispatch **bootstrap-verifier** via the Agent tool. Read `agents/bootstrap-verifier.md`,
pass the prompt to the agent.

The agent checks CLAUDE.md, `.yoke/yoke-context.md`, and the `.yoke/` skeleton and returns:

```yaml
FILES_OK, YOKE_SKELETON_OK, SECTIONS_OK, COMMANDS_OK, PATHS_OK
QUALITY_SCORE: <0-100>
QUALITY_GRADE: <A|B|C|D|F>
ISSUES: <list of problems>
```

### Handling the result

- **YOKE_SKELETON_OK = false** → re-dispatch yoke-context-generator to re-scaffold
  the missing `.yoke/` paths (max 1 retry), then re-verify.
- **QUALITY_GRADE = A and YOKE_SKELETON_OK = true** → transition to Phase 5.
- **QUALITY_GRADE < A and ISSUES is non-empty** → re-dispatch claude-md-generator
  with ISSUES (max 1 retry):
  1. Pass ISSUES to the claude-md-generator agent.
  2. Wait for completion.
  3. Re-dispatch bootstrap-verifier.
  4. If after retry Grade < A → continue with a warning, record VERIFY_NOTES.

Mark in TodoWrite: `[x] Verify`. Transition → Phase 5.

---

## Phase 5 — Flow map

Build `.yoke/flow.md` — the declarative flow map every other skill reads instead
of re-asking the user. Format contract: `reference/flow-md.md`. The orchestrator
gathers the answers through AskUserQuestion (recommended answer first) and writes
the file itself. **Skip any question the repo already answers** — infer the
tracker from the git remote, and the single-repo case from the absence of sibling
checkouts.

Ask, in order:

1. **Repos & finish policy.** Recommended and offered first: single repo — the
   current checkout, role `app`, finish `pr`. Alternative: add linked repos, each
   with a role (`app` | `library`) and finish policy (`pr` | `direct-push`); a
   `direct-push` library also names its publish command and consumer repos. For an
   obvious single-repo project, state the single-repo default and move on without
   forcing the question.
2. **Tracker.** `github` | `youtrack` | `none`, plus the target state `merge`
   moves the ticket to on finish. Recommend and offer first `github` when the
   remote is GitHub; otherwise `none`.
3. **Committed vs local-only** (this extends the old `.gitignore` fork, not a
   separate step). Ask once whether `.yoke/` is **committed** (Recommended — the
   team shares one flow map) or **local-only** (private to this machine). Record
   the answer in flow.md's Artifacts section. On **local-only**, append a
   `.yoke/` line to `.gitignore`.

Write `.yoke/flow.md` with the resolved Repos, Tracker, and Artifacts sections
(omit any section the project does not need — omission means "apply the
default", never "fail"). On re-run, never clobber a hand-edited `.yoke/flow.md` —
show its contents and offer to keep or regenerate.

Mark in TodoWrite: `[x] Flow map`. Transition → Phase 6.

---

## Phase 6 — Confirm

### Notification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ACTION_REQUIRED --skill bootstrap --title "Bootstrap ready" --body "CLAUDE.md, yoke-context.md, and flow.md created"
```

### Show the result

Show the user:

1. **PROJECT_PROFILE summary:** stack, architecture, commands (compact).
2. **CLAUDE.md quality:** Grade + score from verification.
3. **Contents of `.yoke/yoke-context.md`:** first 30 lines.
4. **`.yoke/` skeleton:** the scaffolded layout (`context.md`, `journal.md`, `ai/`, `adr/`).
5. **`.yoke/flow.md`:** the resolved flow map (repos, tracker, artifacts mode).
6. **Recommendations:** RECOMMENDATIONS from automation-recommender.
7. **Notes:** VERIFY_NOTES (if any after retry).

### User choice

AskUserQuestion with 3 options:

1. **Commit (Recommended)** — commit the artifacts and finish.
2. **Review and edit** — the user edits files manually, then re-verify → return to Confirm.
3. **Cancel** — do not commit, exit.

**Handling:**

- **Commit** → transition to Phase 7.
- **Review and edit** → wait for the user's signal, re-dispatch bootstrap-verifier, return to Confirm.
- **Cancel** → tell the user "Bootstrap cancelled. CLAUDE.md, `.yoke/yoke-context.md`, and `.yoke/flow.md` remain on disk." Exit.

Mark in TodoWrite: `[x] Confirm`. Transition → Phase 7.

---

## Phase 7 — Commit

### Stage and commit

**Committed** (default) — `.yoke/` is tracked; flow.md and yoke-context.md ride along:

```bash
git add CLAUDE.md .yoke/
git commit -m "chore: bootstrap yoke flow context and .yoke/ scaffold"
```

**Local-only** — `.yoke/` is gitignored; commit only the repo-level artifacts.
`.yoke/flow.md` and `.yoke/yoke-context.md` stay on disk, untracked:

```bash
git add CLAUDE.md .gitignore
git commit -m "chore: bootstrap yoke flow (local-only .yoke/)"
```

On `index.lock` contention, wait 1–2s and retry.

### Notification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill bootstrap --title "Bootstrap complete" --body "CLAUDE.md + yoke-context.md + flow.md committed"
```

### Summary

Show:

- Commit hash (from `git log -1 --format=%h`).
- Paths to files: `CLAUDE.md`, `.yoke/yoke-context.md`, `.yoke/flow.md`, `.yoke/` (context.md, journal.md, ai/, adr/).
- Artifacts mode: committed or local-only.
- Next step: "The project is ready to work with yoke. Try `/yoke:do` to start the first change."

Mark in TodoWrite: `[x] Commit`.
