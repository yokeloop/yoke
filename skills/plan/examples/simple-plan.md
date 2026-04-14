# Example: simple plan

Shows:

- inline mode for a simple task
- 3 tasks + validation
- Design decisions grounded in code, not guesses
- Minimal context per task

---

## Input — task file

```
docs/ai/112-password-reset-email/112-password-reset-email-task.md
Complexity: simple
```

---

## What plan-explorer found

- `src/auth/login.ts:8-19` — handler pattern: async, zod validation, AppError
- `src/auth/register.ts:31` — crypto.randomBytes for tokens
- `src/models/User.ts:34-35` — fields resetToken/resetTokenExpiry already in the schema
- `src/services/email.ts:12` — method send(to, subject, html)
- `src/routes/auth.ts:28` — route-registration point
- Intersection: `src/routes/auth.ts` changes in Task 1 and Task 2 (adding routes),
  but append-only (different lines) — conflict unlikely

---

## What plan-designer decided

**DD-1:** Token format — crypto.randomBytes(32).toString('hex')
because register.ts:31 follows this pattern.

**DD-2:** Token expiry — 1 hour, constant TOKEN_EXPIRY_MS in config.
Standard for security-sensitive operations; no prior convention in the project.

**Routing:** 3 tasks, one shared file (routes/auth.ts) but append-only → inline.

---

## Final plan file

> Written to `docs/ai/112-password-reset-email/112-password-reset-email-plan.md`

---

# Add password reset via email — implementation plan

**Task:** docs/ai/112-password-reset-email/112-password-reset-email-task.md
**Complexity:** simple
**Mode:** inline
**Parallel:** false

## Design decisions

### DD-1: Reset token format

**Decision:** `crypto.randomBytes(32).toString('hex')` — 64-char hex string.
**Rationale:** Pattern from `src/auth/register.ts:31` — the project already uses this approach.
**Alternative:** UUID v4 — no reason to diverge from the existing pattern.

### DD-2: Token expiry

**Decision:** 1 hour. Constant `RESET_TOKEN_EXPIRY_MS = 3600000` in `src/config/index.ts`.
**Rationale:** Standard for security-sensitive operations. The project has no prior TTL convention.
**Alternative:** 24 hours — less secure for password reset.

## Tasks

### Task 1: forgot-password endpoint

- **Files:** `src/auth/forgot-password.ts` (create), `src/routes/auth.ts:28` (edit — add route)
- **Depends on:** none
- **Scope:** M
- **What:** Create handler POST /auth/forgot-password. Accepts {email}, finds user, generates token, writes to User, sends email. Email not found → 200 (don't leak account existence).
- **Context:** `src/auth/login.ts:8-19` (handler+zod pattern), `src/models/User.ts:34-35` (fields), `src/services/email.ts:12` (send), `src/config/index.ts` (APP_URL, EMAIL_FROM)
- **Verify:** `npm test src/auth/__tests__/forgot-password.test.ts` — green

### Task 2: reset-password endpoint

- **Files:** `src/auth/reset-password.ts` (create), `src/routes/auth.ts` (edit — add route)
- **Depends on:** Task 1
- **Scope:** M
- **What:** Create handler POST /auth/reset-password. Accepts {token, newPassword}, validates token + expiry, updates passwordHash, clears token fields. Invalid/expired → 400.
- **Context:** `src/auth/forgot-password.ts` (Task 1 — how the token was written), `src/models/User.ts:34-35`, `src/auth/login.ts:8-19` (pattern)
- **Verify:** `npm test src/auth/__tests__/reset-password.test.ts` — green

### Task 3: Tests for both endpoints

- **Files:** `src/auth/__tests__/forgot-password.test.ts` (create), `src/auth/__tests__/reset-password.test.ts` (create)
- **Depends on:** Task 1, Task 2
- **Scope:** M
- **What:** Write tests following `src/auth/__tests__/login.test.ts`. Cases: existing email → 200 + token in DB, unknown → 200, valid token → 200 + password updated, expired → 400, reuse → 400.
- **Context:** `src/auth/__tests__/login.test.ts` (template), `src/auth/forgot-password.ts`, `src/auth/reset-password.ts`
- **Verify:** `npm test src/auth/__tests__/` — all green

### Task 4: Validation

- **Files:** —
- **Depends on:** all
- **Scope:** S
- **What:** Run the full validation suite.
- **Context:** —
- **Verify:** `npm test && npm run lint` — all green, 0 new failures

## Execution

- **Mode:** inline
- **Parallel:** false
- **Reasoning:** 3 tasks + validation, all sequential (Task 2 depends on Task 1, tests depend on both), simple task in a single module.
- **Order:** Task 1 → Task 2 → Task 3 → Task 4

## Verification

- `npm test src/auth/__tests__/forgot-password.test.ts` — green
- `npm test src/auth/__tests__/reset-password.test.ts` — green
- `npm test` — full suite, no new failures
- POST /auth/forgot-password with unknown email → 200
- POST /auth/reset-password with expired token → 400

## Materials

- `src/models/User.ts:34-35` — fields resetToken / resetTokenExpiry
- `src/services/email.ts:12` — method send()
- `src/auth/login.ts:8-19` — handler + zod pattern
- `src/auth/__tests__/login.test.ts` — test template
