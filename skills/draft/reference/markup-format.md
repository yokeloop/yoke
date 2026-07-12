# Markup Format

The contract for **Markup** — what `/draft` writes into the code and what `/do` Draft execution consumes and deletes. From the glossary (`.yoke/context.md`):

> **Markup** — the draft's product in code: markers in existing files plus a skeleton (new files, signatures, types) with compilable stub bodies. A temporary artifact living only between draft and do; none of it survives into the ready PR.

> **Marker** — a single markup comment (`TODO(yoke): …`) naming what will be written at that spot. `do` implements markers as a checklist, deleting each with its implementation; a leftover marker blocks the finish.

---

## Marker

One comment in the unified format:

```
TODO(yoke): <what will be written here>
```

Optionally carrying the plan step reference:

```
TODO(yoke): [task 3] parse the retry config; returns RetryPolicy
```

One Marker = one unit of future work at that exact spot. Use the host language's comment syntax (`// TODO(yoke): …`, `# TODO(yoke): …`, `<!-- TODO(yoke): … -->`). Describe the future work — what the code will do, what it returns, what it touches — not the current state. Place the Marker on the line where the code will be written, not at the file header. Two units of work get two Markers.

## Skeleton

New structure appears as real files: modules, signatures, and types that will exist after implementation. Bodies are compilable stubs.

TypeScript/JS:

```typescript
export function parseRetryConfig(raw: unknown): RetryPolicy {
  // TODO(yoke): [task 3] parse the retry config; validate bounds
  throw new Error("TODO");
}
```

Python:

```python
def parse_retry_config(raw: dict) -> RetryPolicy:
    # TODO(yoke): [task 3] parse the retry config; validate bounds
    raise NotImplementedError
```

Go:

```go
func ParseRetryConfig(raw map[string]any) RetryPolicy {
	// TODO(yoke): [task 3] parse the retry config; validate bounds
	panic("TODO")
}
```

## Build invariant

The skeleton must compile / type-check. A working build keeps the LSP alive: the reviewer navigates signatures and types on the Draft PR instead of reading dead text. Red tests on a Draft PR are acceptable; a broken build is not.

## Boundary

Draft does not implement logic. Markers plus signatures show _where_ and _what_; every body stays a stub. A fully typed scaffold with contracts everywhere is explicitly out — that is half the implementation accepted blind, the exact thing Draft exists to prevent. When torn between a stub and a partial implementation, write the stub and a Marker.

## Grep gate

The prefix `TODO(yoke):` is the checklist key.

- `/do` Draft execution walks the Markers as a checklist, deleting each Marker together with its implementation.
- Before the finish, grep the project's source for `TODO(yoke):` — any hit means unfinished work and blocks the ready flip.
- Scope: the gate greps source code only. Exclude `.yoke/` artifacts and documentation that mentions the literal string (like this file).

---

## Format rules

- One Marker = one unit of future work at that exact spot.
- The Marker prefix is always the literal `TODO(yoke):` — the grep gate depends on it.
- Skeleton files are real: correct paths, imports, exports, types.
- Stub bodies only: `throw new Error("TODO")`, `raise NotImplementedError`, `panic("TODO")`, or the language's equivalent.
- The build stays green; tests may be red.
- No implemented logic anywhere in Markup.
