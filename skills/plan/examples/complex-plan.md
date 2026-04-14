# Example: complex plan

Shows:

- sub-agents mode with parallel groups
- Design decisions: two approaches → committed choice
- Cross-file intersection matrix
- DAG with a barrier between groups
- Context isolation per task

---

## Input — task file

```
docs/ai/RSA-44-leaderboard-realtime/RSA-44-leaderboard-realtime-task.md
Complexity: complex
```

---

## What the agents found

> plan-explorer found: SSE is simpler for a read-only stream; the WS server exists
> but is hardcoded for player-station. File intersection: leaderboard.service.ts
> changes in the server task and the tests, but tests depend on implementation → sequential.
>
> plan-designer: picked SSE (approach B from the task file), decomposed into 5 tasks,
> found 2 parallel groups (server and client independent until integration).

---

## Final plan file

> Written to `docs/ai/RSA-44-leaderboard-realtime/RSA-44-leaderboard-realtime-plan.md`

---

# Real-time leaderboard updates — implementation plan

**Task:** docs/ai/RSA-44-leaderboard-realtime/RSA-44-leaderboard-realtime-task.md
**Complexity:** complex
**Mode:** sub-agents
**Parallel:** true

## Design decisions

### DD-1: Transport — SSE instead of WebSocket

**Decision:** Server-Sent Events through a new endpoint `GET /api/leaderboard/stream`.
**Rationale:** The leaderboard is a read-only stream (server → client). SSE: native `EventSource`, no handshake, over standard HTTP. `ws.server.ts` and the player-station protocol stay untouched.
**Alternative:** Extend the WS server (approach A) — refactor of `ws.server.ts:23-45` (hardcoded types), breaks player-station isolation.

### DD-2: Push payload — full state, not diff

**Decision:** On event, push the full leaderboard state (up to 20 entries).
**Rationale:** Payload is ~2KB. A diff approach is more complex (client merge), and the gain at this size is minimal.
**Alternative:** Only changed rows — ~1.5KB saved, more complex implementation.

### DD-3: Fallback — polling as degradation

**Decision:** `useLeaderboard.ts` opens an EventSource; on error/disconnect — fall back to 30-second polling. A "live" / "offline" indicator in the UI.
**Rationale:** The leaderboard runs at a live event, network is unstable. Polling already works — keep it as a safety net.
**Alternative:** SSE without fallback — on disconnect the user sees stale data.

## Tasks

### Task 1: SSE endpoint on the server

- **Files:** `apps/game-api/src/routes/leaderboard-stream.ts` (create), `apps/game-api/src/routes/index.ts` (edit — register)
- **Depends on:** none
- **Scope:** M
- **What:** Create GET /api/leaderboard/stream — SSE endpoint. On connect, send the current state and register the connection in leaderboard.service. Remove on req.on('close').
- **Context:** `apps/game-api/src/routes/leaderboard.ts:1-55` (route pattern), `apps/game-api/src/services/leaderboard.service.ts:34-67` (processEvent)
- **Verify:** `curl -N http://localhost:3000/api/leaderboard/stream` — receives `data:` with JSON

### Task 2: Push logic in leaderboard.service

- **Files:** `apps/game-api/src/services/leaderboard.service.ts` (edit — add SSE push)
- **Depends on:** none
- **Scope:** M
- **What:** Add an SSE-client array. Methods `addClient(res)`, `removeClient(res)`. In `processEvent()`, after the DB write — push newState to every client via `res.write()`.
- **Context:** `apps/game-api/src/services/leaderboard.service.ts:34-67` (current processEvent), `apps/game-api/src/routes/leaderboard-stream.ts` (Task 1 — how clients connect)
- **Verify:** unit test: processEvent() calls write() on every registered client

### Task 3: Client — EventSource + fallback

- **Files:** `apps/leaderboard-screen/src/hooks/useLeaderboard.ts` (edit)
- **Depends on:** none
- **Scope:** M
- **What:** Add EventSource('/api/leaderboard/stream'). On message — `setLeaderboard(data)`. On error — fall back to polling. Add state `isLive: boolean`.
- **Context:** `apps/leaderboard-screen/src/hooks/useLeaderboard.ts:1-45` (current hook, polling at line 23), `apps/leaderboard-screen/src/components/Leaderboard.tsx:1-120` (how the hook is used)
- **Verify:** The component receives updates without reload. On kill-SSE → fallback polling.

### Task 4: positionChanged animation

- **Files:** `apps/leaderboard-screen/src/components/Leaderboard.tsx` (edit — pass the prop)
- **Depends on:** Task 3
- **Scope:** S
- **What:** Compare previous and new leaderboard state. For rows with a changed position pass `positionChanged={true}` to LeaderboardRow. Do not change LeaderboardRow.tsx.
- **Context:** `apps/leaderboard-screen/src/components/LeaderboardRow.tsx:67-89` (animation, prop positionChanged), `apps/leaderboard-screen/src/hooks/useLeaderboard.ts` (Task 3 — how state updates)
- **Verify:** On rank change — the CSS transition fires

### Task 5: Tests

- **Files:** `apps/game-api/src/routes/__tests__/leaderboard-stream.test.ts` (create), `apps/leaderboard-screen/src/hooks/__tests__/useLeaderboard.test.ts` (create)
- **Depends on:** Task 1, Task 2, Task 3
- **Scope:** M
- **What:** Server: SSE endpoint emits an event on processEvent(), connection cleanup on close. Client: hook switches to EventSource, falls back to polling on error.
- **Context:** `apps/game-api/src/routes/__tests__/game-events.test.ts` (test pattern), Task 1–3 files
- **Verify:** `npm test --workspace=apps/game-api && npm test --workspace=apps/leaderboard-screen` — green

### Task 6: Validation

- **Files:** —
- **Depends on:** all
- **Scope:** S
- **What:** Full validation: lint, types, tests in both workspaces.
- **Context:** —
- **Verify:** `npm test --workspace=apps/game-api && npm test --workspace=apps/leaderboard-screen && npm run lint` — all green

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** 5 tasks + validation. Task 1, 2 (server) and Task 3 (client) share no files — they parallelize. Task 4 depends on 3, Task 5 on 1–3. Single codebase; server/client coordination is needed only at integration.
- **Order:**
  ```
  Group 1 (parallel):
    Task 1: SSE endpoint
    Task 2: Push logic
    Task 3: Client EventSource
  ─── barrier ───
  Group 2 (sequential):
    Task 4: Animation (depends on Task 3)
  ─── barrier ───
  Group 3 (sequential):
    Task 5: Tests (depends on 1, 2, 3)
    Task 6: Validation (depends on all)
  ```

## Verification

- `npm test --workspace=apps/game-api` — all tests green
- `npm test --workspace=apps/leaderboard-screen` — all tests green
- player-station emits score_update → leaderboard updates without reload
- Position-change animation fires
- SSE drop → fallback to polling with no data loss
- 3 leaderboard-screens at once → all receive updates

## Materials

- `apps/leaderboard-screen/src/hooks/useLeaderboard.ts:23` — polling
- `apps/leaderboard-screen/src/components/LeaderboardRow.tsx:67-89` — animation
- `apps/game-api/src/services/leaderboard.service.ts:34-67` — processEvent()
- `apps/game-api/src/routes/game-events.ts:71` — event entry point
