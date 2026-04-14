# Synthesize Guide

Read this file in Phase 3 — before writing the task file.

For each of the 5 dimensions: write one sentence of reasoning aloud (a "CoT step"), then formulate the section. CoT prevents hallucinations on non-trivial tasks.

---

## Dimension 1 — Intent Clarity

**Question:** Will two different developers read the Task and do the same thing?

**CoT step:** "What exactly has to happen — add, change, remove, move, rewrite? If I swap the verb for a more specific one, does the meaning shift?"

**Rule:** one verb — one action. Replace vague verbs with concrete ones.

| Vague       | Concrete                                                            |
| ----------- | ------------------------------------------------------------------- |
| process     | parse / write to DB / enqueue                                       |
| improve     | cut response time from ~800ms to <200ms                             |
| fix         | return 404 instead of 500 when the user is not found                |
| add support | accept `multipart/form-data` on endpoint `POST /upload`             |
| refactor    | split `UserService` (src/services/user.ts:1–340) into three classes |

**Task section format:**

```
## Task

Add rate limiting to the middleware `src/api/middleware/auth.ts` —
max 100 requests per minute per IP, respond 429 on overflow.
```

**Anti-pattern:**

```
## Task

Improve API endpoint security.
```

---

## Dimension 2 — Scope Boundaries

**Question:** What is clearly in scope — and, explicitly, what is not?

**CoT step:** "What could the implementer accidentally touch, thinking it's part of the task? What must not be done, even if it seems logical?"

**Rule:** every Constraints bullet answers a concrete risk from the Investigate findings.

**How to fill Constraints:**

After Investigate you have a list of files and dependencies. For each out-of-scope file — decide: mention as "do not touch" or stay silent. Mention when:

- the file is logically adjacent and the implementer might edit it
- the file is fragile (many dependencies, no tests)
- it contains similar code that must not be touched

**Before / After:**

```
# Bad — boilerplate
## Constraints
- Do not break existing functionality
- Follow project code style
- Write clean code
```

```
# Good — concrete risks from Investigate
## Constraints
- Do not change the `IAuthMiddleware` interface (src/api/middleware/types.ts:12–28) —
  7 other middlewares depend on it
- Do not touch `src/api/middleware/logging.ts` — identical pattern,
  but kept separate on purpose (different teams own the files)
- Do not add a Redis dependency — use the existing in-memory store
  from `src/cache/memory-store.ts`
- Do not apply rate limiting to `/health` or `/metrics` endpoints
```

---

## Dimension 3 — Context Anchoring

**Question:** Does the implementer know exactly what they need — no more, no less?

**CoT step:** "Which findings files will the implementer read? Which patterns should they repeat? Where are the entry points and integrations?"

**Rule:** name files with paths and line numbers. Instead of "in the auth module" write `src/auth/middleware.ts:validateToken():89`.

**Context structure — 4 mandatory subsections:**

Context is structured for the consumer (/plan). Each subsection is a separate input for plan-explorer and plan-designer:

```
## Context

### Area architecture

Requests enter through `src/api/router.ts:42` → flow through the middleware chain
in `src/api/middleware/index.ts:buildChain():15` → reach handlers.

Current chain (src/api/middleware/index.ts:15–34):
1. cors() — src/api/middleware/cors.ts
2. bodyParser() — src/api/middleware/body.ts
3. auth() — src/api/middleware/auth.ts  ← change point
4. requestLogger() — src/api/middleware/logging.ts

### Files to change

- `src/api/middleware/auth.ts:45-67` — add rate limiting before validateToken()
- `src/api/middleware/types.ts:8` — extend IMiddleware if needed

### Patterns to reuse

All middlewares follow the `IMiddleware` interface (src/api/middleware/types.ts:8):
return `(req, res, next) => void`, throw `AppError` on rejection.

Similar logic example — WebSocket throttle at `src/ws/throttle.ts:24–67`:
uses a sliding window via `src/cache/memory-store.ts`.

### Tests

Middleware tests live in `src/api/middleware/__tests__/`.
auth.ts coverage — 84% (src/api/middleware/__tests__/auth.test.ts).
```

**Anti-pattern — unstructured Context:**

```
## Context

The project uses Express.js with a middleware architecture.
Authorization is implemented in the middleware module.
There is a cache for data storage.
```

---

## Dimension 4 — Acceptance Criteria

**Question:** Can the implementer verify each criterion without running the whole project?

**CoT step:** "What must work after implementation? Which command will I run to check? What happens at the edges?"

**Rule:** each Verification bullet is a concrete command with an expected result or an observable behavior. Add edge cases from Investigate.

**Before / After:**

```
# Bad — not verifiable
## Verification

- Rate limiting works correctly
- Existing tests pass
- No regressions
```

```
# Good — commands and behavior
## Verification

- `npm test src/api/middleware/__tests__/auth.test.ts` — all tests green
- `npm test` — full suite, no new failures
- 101 curl requests in a row → first 100 return 200, the 101st returns 429
  with body `{"error": "Too Many Requests", "retryAfter": 60}`
- curl from different IPs → limits are independent (IP A does not affect IP B's counter)
- `GET /health` with the limit exhausted → 200 (rate limiting does not apply)
- Server restart → counters reset (in-memory, no persistence required)
```

**Where to pull edge cases from:** task-explorer findings. A `/health` endpoint or multiple IPs in tests signals an important case.

---

## Dimension 5 — Reuse Opportunities

**Question:** Which existing components, functions, and patterns can be reused?

**CoT step:** "What from Investigate already does part of the job? Are there ready abstractions? Which utilities cover part of the requirements?"

**Rule:** for each requirement check — is there an existing solution or part of one in the codebase? Record it under Context → Patterns to reuse.

**Before / After:**

```
# Bad — no reuse analysis
## Context

The project uses Express.js. We need to add rate limiting.
```

```
# Good — concrete reuse opportunities
## Context

### Patterns to reuse

The WebSocket throttle (`src/ws/throttle.ts:24–67`) uses a sliding window
via `src/cache/memory-store.ts`. The same pattern fits HTTP rate limiting.

Utility `createCounter()` in `src/utils/counter.ts:12` — a ready atomic counter,
reuse it for request counting.

`AppError` (`src/errors/app-error.ts:5`) — the project's standard error class.
Use it for 429 Too Many Requests.
```

---

## Complexity classification

Classify complexity before writing the Task — it drives Output Format and Context detail.

| Complexity  | Signals                                                        | Typical Context size         |
| ----------- | -------------------------------------------------------------- | ---------------------------- |
| **trivial** | 1 file, 1–5 lines, no dependencies                             | 2–3 lines                    |
| **simple**  | 1–2 files, clear scope, tests exist                            | 5–15 lines                   |
| **medium**  | 3–7 files, connections to understand, possible regressions     | 15–40 lines                  |
| **complex** | touches architecture / multiple layers / no tests / public API | 40+ lines, data-flow diagram |

**Signs it's harder than it looks:**

- no tests on the touched area → medium at minimum
- change to a public interface (exported types, API endpoint) → +1 level
- several teams own the files → call it out explicitly in Constraints
- task-architect found multiple incompatible patterns → complex, Output Format "2 approaches" required

---

## Clarifying questions

Generate **3–7 questions**. Only the ones whose answer changes implementation.

**Necessity test:** "If I guess the answer — will the implementer get it wrong?" If yes — the question stays. If no — remove it.

**Validate against the user's input:**

Re-read the original input (`$ARGUMENTS` + ticket text). For each candidate question:

1. Did the user specify a concrete decision? → **Remove the question**, fold the decision into Requirements/Constraints as fact.
2. Did the user name a direction without a concrete variant? → **Keep the question**, promote the user's variant as Recommended.
3. Topic absent from the prompt? → **Keep the question** as is.

Anti-pattern: user wrote "spawn next to empty slots" → question "How do we pick a slot farther from occupied ones?" with options. The answer is given — the question is noise.

**Ask questions interactively through AskUserQuestion** (do not write them to the file).

For each question prepare:

- One-sentence text
- 2–4 options with an explanation of each option's impact on implementation
- Recommended option first

**Examples of good questions** (about implementation, not scope):

- "Where to store rate-limiting counters?" → In-memory (current pattern) / Redis (persistent)
- "Count the limit per IP or per user?" → Per IP (simpler) / Per user ID (more precise) / Both

**Anti-pattern — questions not about implementation:**

- What exactly needs to be done?
- Is there a deadline?
- Who reviews this?
