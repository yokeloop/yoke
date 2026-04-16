# Skill /explore

Codebase exploration and brainstorming in interactive Q&A format. Delegates research to a sub-agent,
accumulates findings in a summary chain, and saves an exploration log when done.

## Input

`$ARGUMENTS` — the first question or topic. If empty, asks via AskUserQuestion.

```
/yoke:explore how does authorization work
/yoke:explore compare caching approaches in the project
/yoke:explore what if we replaced REST with gRPC
```

## Phases

| Phase | Name         | What happens                                                              |
| ----- | ------------ | ------------------------------------------------------------------------- |
| 1     | **Init**     | Pick slug, initialize summary chain and QA log                            |
| 2     | **Loop**     | User-driven Q&A: enrich the prompt with context, dispatch explore-agent   |
| 3     | **Finalize** | Sub-agent writes the exploration log                                      |
| 4     | **Complete** | AskUserQuestion: another question / create a task via /yoke:task / finish |

## Output

Exploration log: `docs/ai/<slug>/<slug>-exploration.md`.

Each Q&A entry contains structured sections: question context, answer, details (file:line, code snippets), alternatives (brainstorm), key files, sources. A final summary closes the log.

## Sub-agents

| Agent                | Model  | Role                                                                          |
| -------------------- | ------ | ----------------------------------------------------------------------------- |
| `explore-agent`      | sonnet | Exploration: code search, analysis, structured-output answer                  |
| `explore-log-writer` | haiku  | Writes a structured exploration log to `docs/ai/<slug>/<slug>-exploration.md` |

## Example

```
/yoke:explore how does the notification system work
```

Result: an interactive Q&A session that accumulates context. On completion, an exploration log with findings.

## Connections

Independent skill. After exploration, `/yoke:task` is recommended to create a task based on the findings.
