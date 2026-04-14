# Translation glossary — canonical tone and terminology reference for ticket #53 (T3-T13).

## 1. Recurring section headers

| Russian | English |
| --- | --- |
| `Фаза N` | `Phase N` |
| `Вход` | `Input` |
| `Фазы` | `Phases` |
| `Правила` | `Rules` |
| `Материалы` | `Materials` |
| `Архитектура области` | `Area architecture` |
| `Файлы для изменения` | `Files to change` |
| `Паттерны для повторения` | `Patterns to reuse` |
| `Тесты` | `Tests` |
| `Переход` | `Transition` |

## 2. Recurring imperative phrases and register

| Russian | English |
| --- | --- |
| `Ты — оркестратор.` | `You are the orchestrator.` |
| `Решай, не спрашивай.` | `Decide, don't ask.` |
| `Ответ есть в коде` | `The answer is in the code` |
| `зелёный` (tests passing) | `green` |

Register: imperative active voice, short sentences. Match the tone of `skills/gca/reference/commit-convention.md` and existing English in `skills/plan/agents/plan-designer.md`.

## 3. Field labels (atomic renames already applied in T1)

| Russian | English |
| --- | --- |
| `Сложность` | `Complexity` |
| `Решение` | `Decision` |
| `Обоснование` | `Rationale` |
| `Альтернатива` | `Alternative` |
| `Тикет` | `Ticket` |
| `Тип` | `Type` |

## 4. Notification title strings

| Russian | English |
| --- | --- |
| `Уточняющие вопросы` | `Clarifying questions` |
| `Вопросы по реализации` | `Implementation questions` |
| `Task готов` | `Task ready` |
| `План готов` | `Plan ready` |
| `Task заблокирован` | `Task blocked` |

## 5. R5 language rule replacement text (for T4/T5/T6/T7)

In the four SKILL.md Rules sections (fix, review, explore, bootstrap) containing the literal Russian line `Язык контента — русский` (with any trailing period or dot, or within a bullet), replace with this exact English bullet:

```
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
```

Keep the bullet's indentation and list-marker consistent with surrounding bullets.

## 6. Preservation rules

- Preserve YAML `name:` values byte-identical.
- Preserve code identifiers, paths, structured-output field names (`TICKET_ID`, `TASK_SLUG`, `STATUS`, `BRANCH`, `PUSH_STATUS`, etc.).
- Preserve slash-command names (`/task`, `/plan`, etc.).
- Use em-dash `—` where the Russian source uses it (keep Unicode em-dash).
- Do NOT leave any Cyrillic characters in translated files.

## 7. Common false friends / tone calls

| Russian | English |
| --- | --- |
| `задача` (plan context) | `task` (lowercase unless referring to a named "Task 1") |
| `скилл` | `skill` |
| `реализатор` | `implementer` |
| `заглушка` | `stub` |
| `пользователь` | `user` |
| `ревью` | `review` |
| `коммит` | `commit` |
| `прогон` | `run` (not "pass" or "trip") |
