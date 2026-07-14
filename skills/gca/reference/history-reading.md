# History Reading

The read side of the **git memory** (ADR-0012): how to recover the decision
history that `commit-convention.md` writes into commit messages. Run this
before touching or judging code — the history of a file carries constraints,
rejected approaches, and warnings that never made it into the code itself.

---

## Before modifying a file

```bash
git log -n 20 --format="%h %s" -- <path>   # quick pass over the intents
git log -n 5 -- <path>                     # full messages: bodies + trailers
```

Act on what comes back:

- `Constraint:` — an active rule. Respect it; when the plan conflicts with
  it, surface the conflict instead of silently overriding.
- `Directive:` — a warning from a previous author. Heed it.
- `Rejected:` — a dead end already explored. Do not re-propose it without
  new evidence; when you do, cite what changed.
- Prose bodies — the why behind the current shape. Read them before
  concluding the code is wrong or accidental.

## Before proposing an approach

Check whether it was already tried and dismissed:

```bash
git log --grep="^Rejected:" --format="%h %s%n%b" -- <path>
```

`--grep` is line-oriented: `^Rejected:` anchors to a trailer line. Drop the
`-- <path>` to search the whole history.

## Understanding one line

```bash
git blame -L <start>,<end> <file>   # who last shaped these lines
git show <hash>                     # the full message — body and trailers
```

`git blame` gives the hash; `git show` gives the memory. Two steps from a
puzzling line to the decision behind it.

## Searching wider

```bash
git log --grep="<keyword>"          # search all messages
git log --follow -- <path>          # history across renames
```

## Trailer-aware output

```bash
git log --format="%h %s%n%(trailers:key=Constraint,key=Directive,valueonly=false)" -- <path>
```

`%(trailers:key=...)` prints only the named trailers — useful for harvesting
every active `Constraint:` over a directory in one pass.

---

## Depth

Ten subjects and the last five full messages per touched file is the default;
dig deeper (`--follow`, `--grep` over all history) only when a body references
older context or the file is central to the change. Older projects have
pre-memory history — a one-line commit with no body is normal there and
carries no signal beyond its subject.
