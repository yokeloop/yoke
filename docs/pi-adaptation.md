# Адаптация yoke для pi dev — полное исследование

> Дата: 2026-04-27  
> Версия yoke: 1.0.0

## Содержание

1. [Обзор архитектуры yoke](#1-обзор-архитектуры-yoke)
2. [Критические несовместимости с pi](#2-критические-несовместимости-с-pi)
3. [Плагины pi, решающие основные проблемы](#3-плагины-pi-решающие-основные-проблемы)
4. [Детальный маппинг Claude Code → Pi](#4-детальный-маппинг-claude-code--pi)
5. [Адаптация каждого скилла](#5-адаптация-каждого-скилла)
6. [Остаточные проблемы, не решаемые плагинами](#6-остаточные-проблемы-не-решаемые-плагинами)
7. [Стратегия: универсальные скилы для обеих платформ](#7-стратегия-универсальные-скилы-для-обеих-платформ)
8. [План реализации](#8-план-реализации)
9. [Список файлов к изменению](#9-список-файлов-к-изменению)
10. [Приложения](#приложения)

---

## 1. Обзор архитектуры yoke

Yoke — это набор из 12 скилов для Claude Code, организованных по паттерну «оркестратор → агенты»:

```
skills/
  bootstrap/SKILL.md          # Подготовка проекта для yoke flow
  do/SKILL.md                 # Выполнение задачи по плану
  explore/SKILL.md             # Исследование кодовой базы
  fix/SKILL.md                 # Быстрый фикс
  gca/SKILL.md                 # Git commit с умной группировкой
  gp/SKILL.md                  # Git push с проверками
  gst/SKILL.md                 # Статус разработки
  hi/SKILL.md                  # Приветствие и обзор скилов
  plan/SKILL.md                # Построение плана реализации
  pr/SKILL.md                  # Создание/обновление Pull Request
  review/SKILL.md              # Код-ревью с автофиксами
  task/SKILL.md                # Формулировка задачи для AI

  Каждый скилл:
  ├── SKILL.md                 # Оркестратор (фронтmatter + инструкции)
  ├── agents/                  # Суб-агенты (dispatch через Agent tool)
  ├── reference/               # Справочные материалы
  └── examples/                # Примеры (не у всех)
```

### Ключевые концепции

| Концепция                    | Описание                                | Частота                 |
| ---------------------------- | --------------------------------------- | ----------------------- |
| **Agent tool**               | Dispatch суб-агента из SKILL.md         | 30 агентов, 50+ вызовов |
| **AskUserQuestion**          | Интерактивный Q&A с пользователем       | 6 скилов, 15+ вызовов   |
| **$ARGUMENTS**               | Автоподстановка аргументов команды      | 9 скилов, 20+ вызовов   |
| **${CLAUDE_PLUGIN_ROOT}**    | Путь к корню плагина                    | 6 скилов, 20+ вызовов   |
| **{{PLACEHOLDER}}**          | Шаблонные переменные в промптах агентов | 126 вхождений           |
| **TodoWrite**                | Отслеживание прогресса фаз              | 5 скилов, 15+ вызовов   |
| **model: opus/sonnet/haiku** | Выбор модели в frontmatter агента       | Все 30 агентов          |
| **tools: Read, Write...**    | Ограничение инструментов агента         | Все 30 агентов          |
| **color:**                   | Цветовая метка агента                   | Все 30 агентов          |
| **notify.sh**                | Уведомления через Telegram              | 3 скила, hooks/         |

### Каталог агентов (30 штук)

| Скилл                | Агенты                                                                                                                                                                                                         |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bootstrap (10)       | stack-detector, architecture-mapper, convention-scanner, validation-scanner, existing-rules-detector, domain-analyzer, claude-md-generator, yoke-context-generator, automation-recommender, bootstrap-verifier |
| do (8)               | task-executor, spec-reviewer, quality-reviewer, code-polisher, validator, formatter, doc-updater, report-writer                                                                                                |
| explore (2)          | explore-agent, explore-log-writer                                                                                                                                                                              |
| fix (3 + 3 cross)    | fix-context-collector, fix-investigator, fix-log-writer; + task-executor, code-polisher, validator из do                                                                                                       |
| gca (0)              | — (оркестратор работает напрямую)                                                                                                                                                                              |
| gp (2)               | git-pre-checker, git-pusher                                                                                                                                                                                    |
| gst (1)              | git-data-collector                                                                                                                                                                                             |
| plan (3)             | plan-explorer, plan-designer, plan-reviewer                                                                                                                                                                    |
| pr (2)               | pr-data-collector, pr-body-generator                                                                                                                                                                           |
| review (4 + 2 cross) | code-reviewer, issue-fixer, single-fix-agent, review-report-writer; + validator, formatter из do                                                                                                               |
| task (2)             | task-explorer, task-architect                                                                                                                                                                                  |

---

## 2. Критические несовместимости с pi

### 2.1. Agent tool — главный барьер

Во всех сложных скилах оркестратор dispatch'ит работу агентам через `Agent tool`. Pi **не имеет встроенного Agent tool**.

**Пример из do/SKILL.md:**

```
Dispatch via the Agent tool (model: sonnet). The agent file is already read in Init.
```

**Пример из bootstrap/SKILL.md:**

```
Dispatch 6 agents in parallel via the Agent tool (6 calls at once):
- stack-detector → agents/stack-detector.md
- architecture-mapper → agents/architecture-mapper.md
...
```

### 2.2. AskUserQuestion — интерактивные решения

Оркестраторы принимают решения у пользователя через `AskUserQuestion`:

```
AskUserQuestion with 3 options:
1. Add exception .claude/yoke-context.md to .gitignore
2. Commit only CLAUDE.md
3. Cancel
```

Pi не имеет `AskUserQuestion`.

### 2.3. $ARGUMENTS — аргументы команды

Claude Code автоматически подставляет `$ARGUMENTS` в контекст. Pi передаёт аргументы как текст после `/skill:name`.

### 2.4. ${CLAUDE_PLUGIN_ROOT} — пути к корню

```
${CLAUDE_PLUGIN_ROOT}/skills/do/agents/task-executor.md
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE ...
```

Pi не предоставляет этой переменной и не использует плагинную структуру каталогов агентов.

### 2.5. {{PLACEHOLDER}} — шаблоны в промптах

Оркестратор подставляет данные перед dispatch:

```yaml
TASK_WHAT: { { TASK_WHAT } }
TASK_HOW: { { TASK_HOW } }
PROJECT_PROFILE: { { PROJECT_PROFILE } }
```

126 вхождений. Pi-subagents не поддерживает шаблоны — `task:` это просто строка.

### 2.6. TodoWrite — трекинг фаз

```markdown
Mark in TodoWrite: [x] Detect
Mark in TodoWrite: [x] Execute
```

Pi не имеет TodoWrite. Альтернатива: markdown-чеклисты или встроенный прогресс pi-subagents.

### 2.7. Agent frontmatter — разные форматы

| Поле                    | Claude Code               | Pi (pi-subagents)                                                                    |
| ----------------------- | ------------------------- | ------------------------------------------------------------------------------------ |
| `tools`                 | `Glob, Grep, Read, Bash`  | `find, grep, read, bash, ls`                                                         |
| `model`                 | `opus`, `sonnet`, `haiku` | `anthropic/claude-opus-4`, `anthropic/claude-sonnet-4`, `anthropic/claude-haiku-4-5` |
| `color`                 | `blue`, `cyan`, etc.      | Нет (Pi игнорирует)                                                                  |
| `systemPromptMode`      | Нет                       | `replace` / `append`                                                                 |
| `inheritProjectContext` | Нет                       | `true` / `false`                                                                     |
| `inheritSkills`         | Нет                       | `true` / `false`                                                                     |
| `output`                | Нет                       | `context.md`                                                                         |
| `defaultProgress`       | Нет                       | `true`                                                                               |

### 2.8. Имена встроенных инструментов

| Claude Code    | Pi            | Примечание          |
| -------------- | ------------- | ------------------- |
| `Read`         | `read`        | —                   |
| `Write`        | `write`       | —                   |
| `Edit`         | `edit`        | —                   |
| `Bash`         | `bash`        | —                   |
| `Glob`         | `find` / `ls` | Pi не имеет Glob    |
| `Grep`         | `grep`        | —                   |
| `LS`           | `ls`          | —                   |
| `TodoWrite`    | —             | Убрать              |
| `NotebookRead` | —             | Или `pi-docparser`  |
| `WebFetch`     | —             | Или `pi-web-access` |
| `WebSearch`    | —             | Или `pi-web-access` |
| `KillShell`    | —             | Нет аналога         |
| `BashOutput`   | —             | Нет аналога         |

### 2.9. Контекст проекта

| Аспект           | Claude Code                          | Pi                                    |
| ---------------- | ------------------------------------ | ------------------------------------- |
| Контекстный файл | `.claude/yoke-context.md`            | `.pi/yoke-context.md` или `AGENTS.md` |
| Правила проекта  | `CLAUDE.md`                          | `AGENTS.md` или `.pi/settings.json`   |
| Путь к плагину   | `${CLAUDE_PLUGIN_ROOT}`              | Относительный путь                    |
| Аргументы        | `$ARGUMENTS`                         | Текст после `/skill:name`             |
| Уведомления      | `hooks/hooks.json` + `lib/notify.sh` | pi extension events                   |

---

## 3. Плагины pi, решающие основные проблемы

### 3.1. pi-subagents (v0.19.3) — замена Agent tool

**Установка:** `pi install npm:pi-subagents`

**Возможности:**

- Одиночный dispatch: `subagent({ agent: "stack-detector", task: "..." })`
- Параллельный: `subagent({ tasks: [{ agent: "scout", task: "..." }, ...], concurrency: 6 })`
- Цепочки: `subagent({ chain: [{ agent: "scout", task: "..." }, { agent: "planner" }, ...] })`
- Async/background: `subagent({ agent: "worker", task: "...", async: true })`
- Fork context: `subagent({ agent: "oracle", task: "...", context: "fork" })`
- Выбор модели: в frontmatter агента (`model: anthropic/claude-sonnet-4`)
- Override модели: `/run reviewer[model=anthropic/claude-sonnet-4]`
- Worktrees для параллельной записи: `worktree: true`
- Управление агентами: `subagent({ action: "list" })`, create, update, delete
- `/agents` — интерактивный TUI менеджер
- `/run`, `/chain`, `/parallel` — слэш-команды

**Формат агента:**

```yaml
---
name: my-agent
description: What this agent does
model: anthropic/claude-sonnet-4
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
tools: read, write, edit, bash, find, grep, ls
output: context.md
defaultProgress: true
---
System prompt body...
```

**Обнаружение агентов:**

- `~/.pi/agent/agents/*.md` — глобальные
- `.pi/agents/*.md` — проектные
- `.agents/*.md` — legacy (совместимость)
- `~/.pi/agent/extensions/subagent/agents/` — встроенные

**Маппинг yoke → pi-subagents:**

| yoke                                | pi-subagents                                 |
| ----------------------------------- | -------------------------------------------- |
| `Dispatch agent via the Agent tool` | `subagent({ agent: "...", task: "..." })`    |
| `Dispatch 6 agents in parallel`     | `subagent({ tasks: [...], concurrency: 6 })` |
| `model: opus`                       | `model: anthropic/claude-opus-4`             |
| `model: sonnet`                     | `model: anthropic/claude-sonnet-4`           |
| `model: haiku`                      | `model: anthropic/claude-haiku-4-5`          |
| `tools: Read, Write, Edit, Bash`    | `tools: read, write, edit, bash`             |
| `tools: Glob, Grep`                 | `tools: find, grep`                          |
| `tools: LS`                         | `tools: ls`                                  |

### 3.2. pi-ask-user (v0.6.1) — замена AskUserQuestion

**Установка:** `pi install npm:pi-ask-user`

**Возможности:**

- Interactive TUI с поиском, split-pane preview
- Single-select и multi-select
- Freeform ввод
- Optional comment после выбора
- Overlay mode
- Timeout (автозакрытие)
- Fallback в RPC/headless режиме (через `ctx.ui.select()`)
- Бандлит skill `ask-user` с decision-gate паттерном

**Пример маппинга:**

```markdown
# Claude Code

AskUserQuestion with 3 options:

1. Add exception
2. Commit only
3. Cancel

# Pi

ask_user({
question: "How should we handle yoke-context.md in git?",
context: "CLAUDE.md and yoke-context.md have been generated.",
options: [
{ title: "Add .claude/yoke-context.md exception to .gitignore", description: "Commit both files" },
{ title: "Commit only CLAUDE.md", description: "Skip yoke-context" },
{ title: "Cancel", description: "Don't commit anything" }
],
allowFreeform: true
})
```

### 3.3. pi-intercom (v0.2.1) — координация и уведомления

**Установка:** `pi install npm:pi-intercom`

**Возможности:**

- 1:1 messaging между pi-сессиями
- `intercom({ action: "send", to: "worker", message: "..." })` — отправка
- `intercom({ action: "ask", to: "planner", message: "..." })` — вопрос с блокировкой
- Интеграция с pi-subagents для needs-attention уведомлений
- `/intercom` или Alt+M — TUI

**Замена notify.sh:**
Вместо `bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE ...` можно:

- Для координации оркестратор ↔ агент: `intercom({ action: "send", message: "..." })`
- Для UI уведомлений пользователю: `ctx.ui.notify()` (в pi extension)

### 3.4. Опциональные плагины

| Пакет                      | Заменяет                         | Установка                                 |
| -------------------------- | -------------------------------- | ----------------------------------------- |
| `pi-web-access`            | `WebFetch`, `WebSearch`          | `pi install npm:pi-web-access`            |
| `pi-docparser`             | `NotebookRead` (PDF/Office)      | `pi install npm:pi-docparser`             |
| `pi-lens`                  | Ручные bash-проверки в validator | `pi install npm:pi-lens`                  |
| `pi-prompt-template-model` | Переиспользуемые промпт-шаблоны  | `pi install npm:pi-prompt-template-model` |

---

## 4. Детальный маппинг Claude Code → Pi

### 4.1. Agent tool → subagent()

```markdown
# Claude Code

Dispatch via the Agent tool:

- Agent: `${CLAUDE_PLUGIN_ROOT}/skills/gst/agents/git-data-collector.md`
- Prompt: "Collect data on the current git repository state and produce a report"

# Pi

subagent({
agent: "git-data-collector",
task: "Collect data on the current git repository state and produce a report"
})
```

### 4.2. Параллельный dispatch

```markdown
# Claude Code

Dispatch 6 agents **in parallel** via the Agent tool (6 calls at once):

1. stack-detector → agents/stack-detector.md
2. architecture-mapper → agents/architecture-mapper.md
   ...

# Pi

subagent({
tasks: [
{ agent: "stack-detector", task: "Detect the tech stack..." },
{ agent: "architecture-mapper", task: "Map the architecture..." },
{ agent: "convention-scanner", task: "Scan conventions..." },
{ agent: "validation-scanner", task: "Scan validation..." },
{ agent: "existing-rules-detector", task: "Detect existing rules..." },
{ agent: "domain-analyzer", task: "Analyze the domain..." }
],
concurrency: 6
})
```

### 4.3. Последовательная цепочка

```markdown
# Claude Code (ручной dispatch в SKILL.md)

1. Run task-executor → agents/task-executor.md
2. Then spec-reviewer → agents/spec-reviewer.md
3. Then quality-reviewer → agents/quality-reviewer.md
   ...

# Pi

subagent({
chain: [
{ agent: "task-executor", task: "Implement: ..." },
{ agent: "spec-reviewer", task: "Review spec compliance from {previous}" },
{ agent: "quality-reviewer", task: "Review quality from {previous}" },
{ agent: "code-polisher", task: "Polish code from {previous}" },
{ agent: "validator", task: "Run validation from {previous}" },
{ agent: "doc-updater", task: "Update docs from {previous}" },
{ agent: "formatter", task: "Format from {previous}" },
{ agent: "report-writer", task: "Write report from {previous}" }
]
})
```

### 4.4. AskUserQuestion → ask_user()

```markdown
# Claude Code

AskUserQuestion with 3 options:

1. Add exception `.claude/yoke-context.md` to .gitignore
2. Commit only `CLAUDE.md`
3. Cancel

# Pi

ask_user({
question: "How should we handle the generated files?",
context: "CLAUDE.md and yoke-context.md have been created. .claude/ may be in .gitignore.",
options: [
{ title: "Add .claude/yoke-context.md exception", description: "Commit both files" },
{ title: "Commit only CLAUDE.md", description: "Skip yoke-context" },
{ title: "Cancel", description: "Don't commit anything" }
],
allowFreeform: true
})
```

### 4.5. $ARGUMENTS → prompt-аргументы

```markdown
# Claude Code

$ARGUMENTS — path to a task file, e.g. `docs/ai/86-black-jack-page/86-black-jack-page-task.md`

# Pi

The user's input follows the skill invocation. For `/skill:plan`, the argument
is the path to a task file, e.g. `docs/ai/86-black-jack-page/86-black-jack-page-task.md`.
If the argument is missing — ask via ask_user.
```

### 4.6. CLAUDE_PLUGIN_ROOT → имена агентов / относительные пути

```markdown
# Claude Code

- Implementation → `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/task-executor.md`

# Pi

- Implementation → subagent({ agent: "task-executor", task: "..." })

# Для reference/ файлов в SKILL.md — относительные пути работают в обеих средах:

See [commit convention](reference/commit-convention.md) for details.
```

### 4.7. {{PLACEHOLDER}} шаблоны

Pi-subagents не подставляет шаблоны. Два подхода:

**Подход A: Контекст через task: строку**

```markdown
subagent({
agent: "task-executor",
task: `Implement the following task:

What: ${TASK_WHAT}

How: ${TASK_HOW}

Files to create/change: ${TASK_FILES}

Verify: ${TASK_VERIFY}`
})
```

**Подход B: Контекст через reads: файл**

```markdown
# Оркестратор пишет временый контекстный файл

# затем:

subagent({
agent: "task-executor",
task: "Execute the task per context file",
reads: "context.md"
})
```

### 4.8. TodoWrite → markdown-чеклисты

```markdown
# Claude Code

Mark in TodoWrite: [x] Detect
Mark in TodoWrite: [x] Execute

# Pi: просто текст в SKILL.md

Progress checklist (update as you complete each phase):

- [ ] Detect
- [ ] Execute
- [ ] Generate
- [ ] Verify
```

Или использовать встроенный прогресс pi-subagents (`defaultProgress: true`).

### 4.9. Уведомления (notify.sh) → pi extension

```markdown
# Claude Code

bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ACTION_REQUIRED --skill bootstrap --phase Confirm --slug "bootstrap" --title "Bootstrap ready" --body "CLAUDE.md and yoke-context.md created"

# Pi: через ctx.ui.notify() в extension

ctx.ui.notify("Bootstrap ready: CLAUDE.md and yoke-context.md created", "success");

# Pi: через intercom (для оркестратор ↔ агент координации)

intercom({ action: "send", to: "parent", message: "Bootstrap phase Complete done" })
```

### 4.10. hooks/hooks.json → pi extension

```json
// Claude Code: hooks/hooks.json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/notify.sh",
        "timeout": 10,
        "allowedEnvVars": ["CC_TELEGRAM_BOT_TOKEN", "CC_TELEGRAM_CHAT_ID"]
      }]
    }]
  }
}

// Pi: extension event
pi.on("session_shutdown", async (event, ctx) => {
  // Check for pending notification and send to Telegram
  // Or use ctx.ui.notify() for in-TUI notifications
});
```

---

## 5. Адаптация каждого скилла

### 5.1. hi — 🟢 Лёгкая

Нет агентов, нет `$ARGUMENTS`, нет `AskUserQuestion`. Почти чистый текст.

**Изменения:**

- Обновить префиксы команд: `/yoke:task` → `/skill:task`
- В pi-контексте убрать ссылки на `/yoke:`

### 5.2. gca — 🟡 Средняя

Нет агентов. Есть `$ARGUMENTS`, `AskUserQuestion` и `reference/`.

**Изменения:**

- `$ARGUMENTS` → инструкция про аргументы
- `AskUserQuestion` → `ask_user()`
- `reference/` — оставить как есть (относительные пути)

### 5.3. gst — 🟡 Средняя

1 агент (`git-data-collector`).

**Изменения:**

- `Agent tool` → `subagent({ agent: "git-data-collector", task: "..." })`
- `${CLAUDE_PLUGIN_ROOT}/skills/gst/agents/git-data-collector.md` → имя агента `git-data-collector`

### 5.4. explore — 🟡 Средняя

2 агента, `AskUserQuestion`, `$ARGUMENTS`.

**Изменения:**

- 2 агента → `subagent()`
- `AskUserQuestion` → `ask_user()`
- `$ARGUMENTS` → инструкция

### 5.5. gp — 🟡 Средняя

2 агента.

**Изменения:**

- 2 агента → `subagent()`
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов

### 5.6. pr — 🟡 Средняя

2 агента, `AskUserQuestion`, `$ARGUMENTS`.

**Изменения:**

- 2 агента → `subagent()`
- `AskUserQuestion` → `ask_user()`
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов

### 5.7. task — 🟡 Средняя

2 агента, `KillShell`, `BashOutput`, `WebSearch`, `WebFetch` в frontmatter.

**Изменения:**

- 2 агента → `subagent()`
- Убрать `KillShell`, `BashOutput`, `WebSearch`, `WebFetch` из tools
- Или добавить `pi-web-access` как зависимость

### 5.8. plan — 🔴 Высокая

3 агента, `KillShell`, `BashOutput` в frontmatter, `{{PLACEHOLDER}}`.

**Изменения:**

- 3 агента → `subagent({ chain: [...] })`
- Убрать `KillShell`, `BashOutput`
- Шаблоны → контекст через `task:` или `reads:`

### 5.9. bootstrap — 🔴 Высокая

10 агентов, параллельный dispatch, `{{PLACEHOLDER}}`, `TodoWrite`, `AskUserQuestion`, `.claude/`.

**Изменения:**

- Параллельный dispatch → `subagent({ tasks: [...], concurrency: 6 })`
- `{{PLACEHOLDER}}` → контекст через `task:` строку
- `TodoWrite` → markdown-чеклист
- `AskUserQuestion` → `ask_user()`
- `.claude/` → `.pi/`
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов
- `notify.sh` → pi-integration

### 5.10. do — 🔴 Высокая

8 агентов, последовательные и параллельные фазы, review loop, модель-маршрутизация.

**Изменения:**

- Последовательные фазы → `subagent({ chain: [...] })`
- Параллельные `task-executor` → `subagent({ tasks: [...], concurrency: N })`
- `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` → агент читает файл напрямую
- `TodoWrite` → убрать
- `notify.sh` → pi-intercom / ctx.ui.notify()

### 5.11. fix — 🔴 Высокая

3 собственных + 3 cross-skill агента, `AskUserQuestion`, `CLAUDE_PLUGIN_ROOT`, эскалация на opus.

**Изменения:**

- 6 агентов → `subagent()` по имени (без путей)
- `AskUserQuestion` → `ask_user()`
- Модель-маршрутизация → `model: anthropic/claude-opus-4` в frontmatter агента
- `notify.sh` → pi-intercom

### 5.12. review — 🔴 Высокая

4 собственных + 2 cross-skill агента, параллельные fix-агенты.

**Изменения:**

- 6 агентов → `subagent()` по имени
- Параллельные fix → `subagent({ tasks: [...] })`
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов

---

## 6. Остаточные проблемы, не решаемые плагинами

### 6.1. TodoWrite

**Проблема:** 15+ вызовов в 5 скилах.

**Решение:** Заменить на markdown-чеклисты или полагаться на встроенный прогресс pi-subagents (`defaultProgress: true`). Не критично — это cosmetic tracking.

### 6.2. `.claude/yoke-context.md` → `.pi/`

**Проблема:** Bootstrap генерирует `.claude/yoke-context.md`. Pi ожидает `.pi/`.

**Решение:** В универсальном SKILL.md указать оба пути. Для Pi — генерировать в `.pi/yoke-context.md`.

### 6.3. Уведомления

**Проблема:** `hooks/hooks.json` + `lib/notify.sh` + `hooks/notify.sh` — это Claude Code hooks.

**Решение:** Написать мини-extension `pi-yoke-notify.ts` (~50 строк), который:

1. Регистрирует кастомный инструмент `yoke_notify`
2. Отправляет уведомления через Telegram Bot API
3. Или подписывается на `session_shutdown` для отправки сводки

### 6.4. NotebookRead

**Проблема:** Используется в `task-executor.md`.

**Решение:** Убрать из tools (агент может использовать `read` для текстовых файлов). Для PDF/Office — добавить `pi-docparser`.

### 6.5. KillShell, BashOutput

**Проблема:** Используются в `plan-designer.md`, `plan-explorer.md`, `task-architect.md`, `task-explorer.md`.

**Решение:** Убрать — pi не имеет этих инструментов. Агенты могут прерываться через стандартный механизм pi-subagents.

---

## 7. Стратегия: универсальные скилы для обеих платформ

### 7.1. Почему нельзя полностью унифицировать

Агенты имеют **фундаментально разные** форматы frontmatter:

```yaml
# Claude Code
---
name: task-explorer
description: Deeply analyzes the codebase...
tools: Glob, Grep, LS, Read, Bash, WebSearch, WebFetch, TodoWrite
model: sonnet
color: yellow
---
# Pi (pi-subagents)
---
name: task-explorer
description: Deeply analyzes the codebase...
tools: find, grep, ls, read, bash
model: anthropic/claude-sonnet-4
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
output: context.md
defaultProgress: true
---
```

Нельзя положить оба формата в один файл.

### 7.2. Рекомендуемая стратегия: единый источник правды

```
yoke/
  agents/                     # Единый источник правды — 30 файлов
    stack-detector.md          # Тело промпта + мета-данные для генератора
    task-executor.md
    ...

  skills/                     # Универсальные SKILL.md — 12 файлов
    task/SKILL.md              # Dual-instructions (CC + Pi)
    plan/SKILL.md
    ...
    task/reference/             # Референсы (общие)
      elements-of-style-rules.md
      ...

  scripts/
    build-agents.ts            # Генератор: agents/* → agents-cc/* + agents-pi/*

  lib/
    notify.sh                  # CC уведомления

  hooks/
    hooks.json                 # CC hooks

  .pi/agents/                  # ← Генерируется: Pi-формат
  skills/*/agents/             # ← Генерируется: CC-формат

  .pi/settings.json            # Pi-конфигурация пакетов
```

### 7.3. Формат единого агента

````yaml
# agents/stack-detector.md

---
# CC frontmatter (генерируется в skills/*/agents/stack-detector.md)
# cc-tools: Bash, Glob, Read
# cc-model: haiku

# Pi frontmatter (генерируется в .pi/agents/stack-detector.md)
# pi-tools: bash, find, read, ls
# pi-model: anthropic/claude-haiku-4-5
# pi-systemPromptMode: replace
# pi-inheritProjectContext: true
# pi-inheritSkills: false
# pi-output: context.md
# pi-defaultProgress: true
---

# Stack Detector

Detects the tech stack of the project: languages, frameworks, build tools, package managers.

## Process

1. **Package manifests** — check for `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, etc.
2. **Config files** — check for `.eslintrc`, `tsconfig.json`, `Dockerfile`, `docker-compose.yml`
3. **Lock files** — check for `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
...

## Structured Output

Return the data strictly in this format:

```yaml
LANGUAGES:
  - <language>: <percentage or presence indicator>
  ...
FRAMEWORKS:
  - <framework>: <version if detectable>
  ...
BUILD_TOOLS:
  - <tool>: <config file>
  ...
````

## Rules

- Read-only.
- Command error — record it and continue.
- Return data. The orchestrator makes decisions.

````

### 7.4. Universal SKILL.md шаблон

```markdown
---
name: task
description: >-
  Draft a task file for AI implementation. Triggered when the user writes
  "create a task", "task from ticket", "draft a task", "prepare an implementation
  prompt", or passes a ticket URL / feature description.
---

# Draft a task for AI implementation

You are the orchestrator. Coordinate sub-agents and talk to the user.

Delegate codebase investigation through the available delegation tool:

## Input

The user's input follows the skill invocation. It contains one or both of:
- **Ticket URL** — GitHub Issues, YouTrack, Jira, etc.
- **Task text** — description, code snippets, links

If the input is empty, ask for a description:

<!-- CC: AskUserQuestion -->
<!-- Pi: ask_user({ question: "What task would you like to draft?", allowFreeform: true }) -->

## Delegation

Delegate investigation tasks:

<!-- CC: Dispatch via Agent tool. Read `agents/task-explorer.md` and `agents/task-architect.md`. -->
<!-- Pi: Use subagent({ agent: "task-explorer", task: "..." }) and subagent({ agent: "task-architect", task: "..." }) -->

...

## Project Context

<!-- CC: Read `.claude/yoke-context.md` if it exists. -->
<!-- Pi: Read `.pi/yoke-context.md` or `AGENTS.md` if it exists. -->

...
````

### 7.5. Скрипт build-agents.ts

```typescript
// scripts/build-agents.ts
// Читает yoke/agents/*.md
// Для каждого файла:
//   1. Извлекает CC/Pi мета-данные из комментариев
//   2. Генерирует CC-формат → skills/<parent>/agents/<name>.md
//   3. Генерирует Pi-формат → .pi/agents/<name>.md

import * as fs from "fs";
import * as path from "path";

const AGENTS_DIR = "agents";
const PI_AGENTS_DIR = ".pi/agents";
const CC_SKILLS_DIR = "skills";

// Маппинг: имя агента → родительский скилл
const AGENT_TO_SKILL: Record<string, string> = {
  "stack-detector": "bootstrap",
  "architecture-mapper": "bootstrap",
  // ...
  "task-executor": "do",
  // ...
};

// Маппинг: CC tool name → Pi tool name
const CC_TO_PI_TOOLS: Record<string, string> = {
  Read: "read",
  Write: "write",
  Edit: "edit",
  Bash: "bash",
  Glob: "find",
  Grep: "grep",
  LS: "ls",
  NotebookRead: "",
  WebFetch: "",
  WebSearch: "",
  TodoWrite: "",
  KillShell: "",
  BashOutput: "",
};

// Маппинг: CC model name → Pi model name
const CC_TO_PI_MODEL: Record<string, string> = {
  opus: "anthropic/claude-opus-4",
  sonnet: "anthropic/claude-sonnet-4",
  haiku: "anthropic/claude-haiku-4-5",
};

interface AgentMeta {
  ccTools: string;
  ccModel: string;
  piTools: string;
  piModel: string;
  piSystemPromptMode: string;
  piInheritProjectContext: boolean;
  piInheritSkills: boolean;
  piOutput?: string;
  piDefaultProgress: boolean;
  body: string;
  name: string;
  description: string;
}

function parseAgent(content: string, filename: string): AgentMeta {
  // Извлечь frontmatter и тело
  // Извлечь CC/Pi мета из комментариев
  // Сформировать AgentMeta
  // ...
}

function generateCC(agent: AgentMeta): string {
  const frontmatter = [
    "---",
    `name: ${agent.name}`,
    `description: ${agent.description}`,
    `tools: ${agent.ccTools}`,
    `model: ${agent.ccModel}`,
    "---",
  ].join("\n");
  return frontmatter + "\n" + agent.body;
}

function generatePi(agent: AgentMeta): string {
  const frontmatter = [
    "---",
    `name: ${agent.name}`,
    `description: ${agent.description}`,
    `tools: ${agent.piTools}`,
    `model: ${agent.piModel}`,
    `systemPromptMode: ${agent.piSystemPromptMode}`,
    `inheritProjectContext: ${agent.piInheritProjectContext}`,
    `inheritSkills: ${agent.piInheritSkills}`,
    agent.piOutput ? `output: ${agent.piOutput}` : "",
    `defaultProgress: ${agent.piDefaultProgress}`,
    "---",
  ]
    .filter(Boolean)
    .join("\n");
  return frontmatter + "\n" + agent.body;
}

// Main
const agents = fs.readdirSync(AGENTS_DIR).filter((f) => f.endsWith(".md"));

for (const file of agents) {
  const content = fs.readFileSync(path.join(AGENTS_DIR, file), "utf-8");
  const agent = parseAgent(content, file);

  // Генерировать CC
  const skill = AGENT_TO_SKILL[agent.name];
  if (skill) {
    const ccDir = path.join(CC_SKILLS_DIR, skill, "agents");
    fs.mkdirSync(ccDir, { recursive: true });
    fs.writeFileSync(path.join(ccDir, file), generateCC(agent));
  }

  // Генерировать Pi
  fs.mkdirSync(PI_AGENTS_DIR, { recursive: true });
  fs.writeFileSync(path.join(PI_AGENTS_DIR, file), generatePi(agent));
}
```

---

## 8. План реализации

### Фаза 1: Инфраструктура (1-2 дня)

1. Установить плагины:

   ```bash
   pi install npm:pi-subagents
   pi install npm:pi-ask-user
   pi install npm:pi-intercom
   ```

2. Создать `.pi/settings.json` с конфигурацией:

   ```json
   {
     "skills": ["./skills"],
     "subagents": {
       "agentOverrides": {}
     }
   }
   ```

3. Создать `.pi/agents/` директорию.

4. Написать `scripts/build-agents.ts` — генератор CC/Pi форматов из единого источника.

### Фаза 2: Простые скилы (1-2 дня)

Адаптировать в порядке сложности:

1. **hi** — обновить префиксы команд
2. **gca** — `AskUserQuestion` → `ask_user()`, `$ARGUMENTS` → инструкция
3. **gst** — `Agent tool` → `subagent()`, 1 агент

### Фаза 3: Средние скилы (2-3 дня)

4. **explore** — 2 агента, `AskUserQuestion`, `$ARGUMENTS`
5. **gp** — 2 агента, `CLAUDE_PLUGIN_ROOT`
6. **pr** — 2 агента, `AskUserQuestion`, `$ARGUMENTS`
7. **task** — 2 агента, убрать CC-специфичные tools

### Фаза 4: Сложные скилы (3-5 дней)

8. **plan** — 3 агента, цепочка, шаблоны
9. **bootstrap** — 10 агентов, параллельный dispatch, `.claude/` → `.pi/`
10. **do** — 8 агентов, цепочки, review loop
11. **fix** — 6 агентов (cross-skill ссылки), `ask_user()`, эскалация
12. **review** — 6 агентов, параллельные fix-агенты

### Фаза 5: Инфраструктурные (1-2 дня)

13. Написать `pi-yoke-notify` extension (~50 строк)
14. Адаптировать `bootstrap` для `.pi/`
15. Тестирование на обоих платформах

**Итого: ~8-14 дней**

---

## 9. Список файлов к изменению

### SKILL.md (12 файлов — переписать с dual-instructions)

| Файл                        | Сложность | Ключевые изменения                                     |
| --------------------------- | --------- | ------------------------------------------------------ |
| `skills/hi/SKILL.md`        | 🟢        | Обновить префиксы команд                               |
| `skills/gca/SKILL.md`       | 🟡        | `AskUserQuestion` → `ask_user()`, `$ARGUMENTS`         |
| `skills/gst/SKILL.md`       | 🟡        | `Agent tool` → `subagent()`                            |
| `skills/explore/SKILL.md`   | 🟡        | `Agent`, `AskUserQuestion`, `$ARGUMENTS`               |
| `skills/gp/SKILL.md`        | 🟡        | `Agent`, `CLAUDE_PLUGIN_ROOT`                          |
| `skills/pr/SKILL.md`        | 🟡        | `Agent`, `AskUserQuestion`                             |
| `skills/task/SKILL.md`      | 🟡        | `Agent`, убрать CC tools                               |
| `skills/plan/SKILL.md`      | 🔴        | `Agent` chain, шаблоны, CC tools                       |
| `skills/bootstrap/SKILL.md` | 🔴        | Параллельный dispatch, `{{PLACEHOLDER}}`, `.claude/`   |
| `skills/do/SKILL.md`        | 🔴        | Chain, review loop, `CLAUDE_PLUGIN_ROOT`, `TodoWrite`  |
| `skills/fix/SKILL.md`       | 🔴        | Cross-skill агенты, `ask_user()`, модель-маршрутизация |
| `skills/review/SKILL.md`    | 🔴        | Параллельные fix, cross-skill ссылки                   |

### Агенты (30 файлов — адаптировать frontmatter + содержимое)

| Агент                   | CC tools убрать                                       | CC tools → Pi tools                                                       | CC model → Pi model              |
| ----------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------- | -------------------------------- |
| stack-detector          | —                                                     | Bash→bash, Glob→find, Read→read                                           | haiku→anthropic/claude-haiku-4-5 |
| architecture-mapper     | —                                                     | Glob→find, Grep→grep, Read→read, Bash→bash                                | sonnet→anthropic/claude-sonnet-4 |
| convention-scanner      | —                                                     | Glob→find, Grep→grep, Read→read                                           | sonnet→anthropic/claude-sonnet-4 |
| validation-scanner      | —                                                     | Bash→bash, Glob→read, Read→read                                           | haiku→anthropic/claude-haiku-4-5 |
| existing-rules-detector | —                                                     | Bash→bash, Read→read, Glob→find                                           | haiku→anthropic/claude-haiku-4-5 |
| domain-analyzer         | —                                                     | Glob→find, Grep→grep, Read→read, Bash→bash                                | sonnet→anthropic/claude-sonnet-4 |
| claude-md-generator     | —                                                     | Read→read, Write→write, Edit→edit, Glob→find                              | sonnet→anthropic/claude-sonnet-4 |
| yoke-context-generator  | —                                                     | Read→read, Write→write, Bash→bash, Glob→find                              | haiku→anthropic/claude-haiku-4-5 |
| automation-recommender  | —                                                     | Read→read                                                                 | haiku→anthropic/claude-haiku-4-5 |
| bootstrap-verifier      | —                                                     | Read→read, Bash→bash, Glob→find                                           | sonnet→anthropic/claude-sonnet-4 |
| task-executor           | NotebookRead, WebFetch, TodoWrite                     | Read→read, Write→write, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls | opus→anthropic/claude-opus-4     |
| spec-reviewer           | —                                                     | Read→read, Glob→find, Grep→grep, LS→ls                                    | sonnet→anthropic/claude-sonnet-4 |
| quality-reviewer        | —                                                     | Read→read, Glob→find, Grep→grep, LS→ls, Bash→bash                         | sonnet→anthropic/claude-sonnet-4 |
| code-polisher           | —                                                     | Read→read, Write→write, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls | opus→anthropic/claude-opus-4     |
| validator               | —                                                     | Read→read, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls              | haiku→anthropic/claude-haiku-4-5 |
| formatter               | —                                                     | Read→read, Bash→bash, Glob→find, Grep→grep, LS→ls                         | haiku→anthropic/claude-haiku-4-5 |
| doc-updater             | —                                                     | Read→read, Write→write, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls | sonnet→anthropic/claude-sonnet-4 |
| report-writer           | —                                                     | Read→read, Write→write, Bash→bash, Glob→find, LS→ls                       | haiku→anthropic/claude-haiku-4-5 |
| explore-agent           | WebSearch, WebFetch                                   | Glob→find, Grep→grep, LS→ls, Read→read, Bash→bash                         | sonnet→anthropic/claude-sonnet-4 |
| explore-log-writer      | —                                                     | Read→read, Write→write, Edit→edit, Bash→bash                              | haiku→anthropic/claude-haiku-4-5 |
| fix-context-collector   | —                                                     | Bash→bash, Glob→find, LS→ls                                               | haiku→anthropic/claude-haiku-4-5 |
| fix-investigator        | —                                                     | Glob→find, Grep→grep, LS→ls, Read→read, Bash→bash                         | sonnet→anthropic/claude-sonnet-4 |
| fix-log-writer          | —                                                     | Read→read, Write→write, Edit→edit, Bash→bash                              | haiku→anthropic/claude-haiku-4-5 |
| git-data-collector      | —                                                     | Bash→bash                                                                 | haiku→anthropic/claude-haiku-4-5 |
| git-pre-checker         | —                                                     | Bash→bash                                                                 | haiku→anthropic/claude-haiku-4-5 |
| git-pusher              | —                                                     | Bash→bash                                                                 | haiku→anthropic/claude-haiku-4-5 |
| plan-explorer           | KillShell, BashOutput, WebSearch, WebFetch, TodoWrite | Glob→find, Grep→grep, LS→ls, Read→read                                    | sonnet→anthropic/claude-sonnet-4 |
| plan-designer           | KillShell, BashOutput, WebSearch, WebFetch, TodoWrite | Glob→find, Grep→grep, LS→ls, Read→read                                    | opus→anthropic/claude-opus-4     |
| plan-reviewer           | NotebookRead                                          | Glob→find, Grep→grep, LS→ls, Read→read                                    | sonnet→anthropic/claude-sonnet-4 |
| pr-data-collector       | —                                                     | Bash→bash, Read→read, Glob→find                                           | haiku→anthropic/claude-haiku-4-5 |
| pr-body-generator       | —                                                     | Read→read                                                                 | sonnet→anthropic/claude-sonnet-4 |
| code-reviewer           | —                                                     | Read→read, Bash→bash, Glob→find, Grep→grep                                | sonnet→anthropic/claude-sonnet-4 |
| issue-fixer             | —                                                     | Read→read, Bash→bash, Glob→find, Grep→grep                                | sonnet→anthropic/claude-sonnet-4 |
| single-fix-agent        | —                                                     | Read→read, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls              | opus→anthropic/claude-opus-4     |
| review-report-writer    | —                                                     | Read→read, Write→write, Bash→bash, Glob→find, Grep→grep                   | sonnet→anthropic/claude-sonnet-4 |
| task-explorer           | KillShell, BashOutput, WebSearch, WebFetch, TodoWrite | Glob→find, Grep→grep, LS→ls, Read→read                                    | sonnet→anthropic/claude-sonnet-4 |
| task-architect          | KillShell, BashOutput, WebSearch, WebFetch, TodoWrite | Glob→find, Grep→grep, LS→ls, Read→read                                    | opus→anthropic/claude-opus-4     |

### Инфраструктурные файлы

| Файл                      | Действие                                |
| ------------------------- | --------------------------------------- |
| `.pi/settings.json`       | Создать — конфигурация пакетов и скилов |
| `.pi/agents/*.md`         | Создать — 30 Pi-агентов (генерируется)  |
| `scripts/build-agents.ts` | Создать — генератор CC/Pi форматов      |
| `package.json`            | Обновить — добавить build-скрипты       |
| `pi-yoke-notify.ts`       | Создать — pi extension для уведомлений  |
| `skills/*/agents/*.md`    | Обновить — CC-агенты (генерируется)     |

---

## Приложение A: Полный маппинг frontmatter агентов

### Все 37 агентов (включая cross-skill ссылки)

```
Агент                  | CC tools                                    | CC model | Pi tools ( proposed)                    | Pi model
-----------------------|---------------------------------------------|----------|----------------------------------------|----
stack-detector          | Bash, Glob, Read                            | haiku    | bash, find, read, ls                   | anthropic/claude-haiku-4-5
architecture-mapper    | Glob, Grep, Read, Bash                      | sonnet   | find, grep, read, bash, ls             | anthropic/claude-sonnet-4
convention-scanner     | Glob, Grep, Read                            | sonnet   | find, grep, read, ls                  | anthropic/claude-sonnet-4
validation-scanner     | Bash, Glob, Read                            | haiku    | bash, find, read, ls                   | anthropic/claude-haiku-4-5
existing-rules-detector| Bash, Read, Glob                            | haiku    | bash, read, find, ls                  | anthropic/claude-haiku-4-5
domain-analyzer        | Glob, Grep, Read, Bash                     | sonnet   | find, grep, read, bash, ls             | anthropic/claude-sonnet-4
claude-md-generator   | Read, Write, Edit, Glob                    | sonnet   | read, write, edit, find, ls            | anthropic/claude-sonnet-4
yoke-context-generator| Read, Write, Bash, Glob                     | haiku    | read, write, bash, find, ls             | anthropic/claude-haiku-4-5
automation-recommender| Read                                        | haiku    | read                                    | anthropic/claude-haiku-4-5
bootstrap-verifier     | Read, Bash, Glob                            | sonnet   | read, bash, find, ls                   | anthropic/claude-sonnet-4
task-executor          | Read, Write, Edit, Bash, Glob, Grep, LS, NotebookRead, WebFetch, TodoWrite | opus | read, write, edit, bash, find, grep, ls | anthropic/claude-opus-4
spec-reviewer          | Read, Glob, Grep, LS                        | sonnet   | read, find, grep, ls                   | anthropic/claude-sonnet-4
quality-reviewer       | Read, Glob, Grep, LS, Bash                  | sonnet   | read, find, grep, ls, bash             | anthropic/claude-sonnet-4
code-polisher          | Read, Write, Edit, Bash, Glob, Grep, LS     | opus     | read, write, edit, bash, find, grep, ls| anthropic/claude-opus-4
validator              | Read, Edit, Bash, Glob, Grep, LS            | haiku    | read, edit, bash, find, grep, ls       | anthropic/claude-haiku-4-5
formatter              | Read, Bash, Glob, Grep, LS                  | haiku    | read, bash, find, grep, ls             | anthropic/claude-haiku-4-5
doc-updater            | Read, Write, Edit, Bash, Glob, Grep, LS     | sonnet   | read, write, edit, bash, find, grep, ls| anthropic/claude-sonnet-4
report-writer          | Read, Write, Bash, Glob, LS                 | haiku    | read, write, bash, find, ls             | anthropic/claude-haiku-4-5
explore-agent          | Glob, Grep, LS, Read, Bash, WebSearch, WebFetch | sonnet | find, grep, ls, read, bash          | anthropic/claude-sonnet-4
explore-log-writer    | Read, Write, Edit, Bash                     | haiku    | read, write, edit, bash                 | anthropic/claude-haiku-4-5
fix-context-collector  | Bash, Glob, LS                              | haiku    | bash, find, ls                          | anthropic/claude-haiku-4-5
fix-investigator       | Glob, Grep, LS, Read, Bash                 | sonnet   | find, grep, ls, read, bash             | anthropic/claude-sonnet-4
fix-log-writer         | Read, Write, Edit, Bash                     | haiku    | read, write, edit, bash                 | anthropic/claude-haiku-4-5
git-data-collector    | Bash                                        | haiku    | bash                                    | anthropic/claude-haiku-4-5
git-pre-checker       | Bash                                        | haiku    | bash                                    | anthropic/claude-haiku-4-5
git-pusher             | Bash                                        | haiku    | bash                                    | anthropic/claude-haiku-4-5
plan-explorer          | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput | sonnet | find, grep, ls, read             | anthropic/claude-sonnet-4
plan-designer          | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput | opus | find, grep, ls, read            | anthropic/claude-opus-4
plan-reviewer          | Glob, Grep, LS, Read, NotebookRead          | sonnet   | find, grep, ls, read                   | anthropic/claude-sonnet-4
pr-data-collector     | Bash, Read, Glob                            | haiku    | bash, read, find                        | anthropic/claude-haiku-4-5
pr-body-generator     | Read                                        | sonnet   | read                                    | anthropic/claude-sonnet-4
code-reviewer          | Read, Bash, Glob, Grep                      | sonnet   | read, bash, find, grep                 | anthropic/claude-sonnet-4
issue-fixer            | Read, Bash, Glob, Grep                      | sonnet   | read, bash, find, grep                 | anthropic/claude-sonnet-4
single-fix-agent       | Read, Edit, Bash, Glob, Grep, LS            | opus     | read, edit, bash, find, grep, ls       | anthropic/claude-opus-4
review-report-writer  | Read, Write, Bash, Glob, Grep               | sonnet   | read, write, bash, find, grep           | anthropic/claude-sonnet-4
task-explorer          | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput | sonnet | find, grep, ls, read             | anthropic/claude-sonnet-4
task-architect         | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput | opus | find, grep, ls, read            | anthropic/claude-opus-4
```

## Приложение B: Полный каталог плагинов pi

| Пакет                      | Версия | Назначение                                                                  | Обязательность    |
| -------------------------- | ------ | --------------------------------------------------------------------------- | ----------------- |
| `pi-subagents`             | 0.19.3 | Суб-агенты, цепочки, параллельный dispatch, fork-контекст, модель на агента | **Обязательный**  |
| `pi-ask-user`              | 0.6.1  | Интерактивный Q&A (замена AskUserQuestion)                                  | **Обязательный**  |
| `pi-intercom`              | 0.2.1  | Координация оркестратор ↔ агент, уведомления                                | **Рекомендуемый** |
| `pi-web-access`            | latest | WebSearch, WebFetch (замена CC инструментов)                                | Опциональный      |
| `pi-docparser`             | latest | PDF/Office парсинг (замена NotebookRead)                                    | Опциональный      |
| `pi-lens`                  | 3.8.33 | LSP/линтер в риалтайм (замена ручных проверок)                              | Опциональный      |
| `pi-prompt-template-model` | latest | Переиспользуемые промпт-шаблоны                                             | Опциональный      |

## Приложение C: Pi-subagents agent frontmatter reference

```yaml
---
name: my-agent # 1-64 chars, lowercase a-z 0-9 hyphens
description: What this agent does # Max 1024 chars
tools: read, write, edit, bash, find, grep, ls # Tool allowlist
model: anthropic/claude-sonnet-4 # Default model
fallbackModels: # Ordered backup models
  - openai/gpt-5-mini
  - anthropic/claude-haiku-4-5
thinking: high # Thinking level: off, minimal, low, medium, high, xhigh
systemPromptMode: replace # replace (default) or append
inheritProjectContext: true # Keep project instructions
inheritSkills: false # Keep skills catalog
skills: safe-bash, chrome-devtools # Inject specific skills
output: context.md # Default output file
defaultReads: context.md # Files to read before running
defaultProgress: true # Maintain progress.md
interactive: true # Parsed for compatibility
maxSubagentDepth: 1 # Tighten nested delegation
extensions: # Empty = no extensions
---
System prompt body...
```

## Приложение D: Pi-ask-user tool parameters

```json
{
  "question": "Which option should we use?",
  "context": "Short summary of findings",
  "options": [
    { "title": "Option A", "description": "Faster but less extensible" },
    { "title": "Option B", "description": "More effort, cleaner long-term" }
  ],
  "allowMultiple": false,
  "allowFreeform": true,
  "allowComment": false,
  "timeout": null
}
```

Response:

```json
{
  "kind": "selection",
  "selections": ["Option A"],
  "comment": null
}
```

or

```json
{
  "kind": "freeform",
  "text": "I want something different..."
}
```
