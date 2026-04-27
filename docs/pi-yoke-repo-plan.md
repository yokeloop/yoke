# План создания репозитория yoke-pi

> Дата: 2026-04-27
> Статус: Черновик

## Содержание

1. [Обзор и цели](#1-обзор-и-цели)
2. [Структура репозитория](#2-структура-репозитория)
3. [Фаза 0: Подготовка репозитория](#3-фаза-0-подготовка-репозитория)
4. [Фаза 1: Инфраструктура и пакеты](#4-фаза-1-инфраструктура-и-пакеты)
5. [Фаза 2: Агенты — единый источник правды](#5-фаза-2-агенты--единый-источник-правды)
6. [Фаза 3: SKILL.md — универсальные оркестраторы](#6-фаза-3-skillmd--универсальные-оркестраторы)
7. [Фаза 4: Портирование скилов — по порядку сложности](#7-фаза-4-портирование-скилов--по-порядку-сложности)
8. [Фаза 5: Расширения и уведомления](#8-фаза-5-расширения-и-уведомления)
9. [Фаза 6: Документация и CI](#9-фаза-6-документация-и-ci)
10. [Фаза 7: Тестирование и полировка](#10-фаза-7-тестирование-и-полировка)
11. [Критерии приёмки](#11-критерии-приёмки)
12. [Риски](#12-риски)
13. [Оценка трудозатрат](#13-оценка-трудозатрат)
14. [Приложения](#приложения)

---

## 1. Обзор и цели

### Что делаем

Полный клон репозитория `yokeloop/yoke`, переписанный под экосистему pi dev. Новое название: **`yoke-pi`** (репозиторий `yokeloop/yoke-pi`).

### Цели

1. **Полный паритет функциональности** — все 12 скилов работают в pi так же, как в Claude Code
2. **Совместимость с pi-плагинами** — pi-subagents, pi-ask-user, pi-intercom
3. **Нативные pi-паттерны** — `subagent()`, `ask_user()`, `.pi/` вместо `.claude/`, AGENTS.md
4. **Установка одной командой** — `pi install npm:yoke-pi` (или `pi install git:yokeloop/yoke-pi`)
5. **Обратная совместимость знаний** — архитектура скилов, фазы, артефакты (task.md, plan.md, report.md) те же

### Чего мы НЕ делаем

- ❌ Поддержка двух харнесов в одном репозитории одновременно — слишком дорого
- ❌ Универсальные SKILL.md с `<!-- CC -->` / `<!-- Pi -->` условиями — каждый скилл переписан целиком под pi
- ❌ Сохранение Claude Code плагина — оригинальный `yoke` остаётся в `yokeloop/yoke`

---

## 2. Структура репозитория

```
yoke-pi/
├── package.json                    # npm-пакет yoke-pi
├── README.md                       # Документация
├── LICENSE                         # MIT
├── AGENTS.md                       # Инструкции для pi (вместо CLAUDE.md)
├── .gitignore
├── .editorconfig
├── .prettierrc.json
├── .prettierignore
├── .husky/
│   └── pre-commit                  # prettier
│
├── agents/                         # Единый источник правды — 37 агентов
│   ├── stack-detector.md
│   ├── architecture-mapper.md
│   ├── convention-scanner.md
│   ├── validation-scanner.md
│   ├── existing-rules-detector.md
│   ├── domain-analyzer.md
│   ├── claude-md-generator.md      # → переименовать в project-md-generator.md
│   ├── yoke-context-generator.md
│   ├── automation-recommender.md
│   ├── bootstrap-verifier.md
│   ├── task-executor.md
│   ├── spec-reviewer.md
│   ├── quality-reviewer.md
│   ├── code-polisher.md
│   ├── validator.md
│   ├── formatter.md
│   ├── doc-updater.md
│   ├── report-writer.md
│   ├── explore-agent.md
│   ├── explore-log-writer.md
│   ├── fix-context-collector.md
│   ├── fix-investigator.md
│   ├── fix-log-writer.md
│   ├── git-data-collector.md
│   ├── git-pre-checker.md
│   ├── git-pusher.md
│   ├── plan-explorer.md
│   ├── plan-designer.md
│   ├── plan-reviewer.md
│   ├── pr-data-collector.md
│   ├── pr-body-generator.md
│   ├── code-reviewer.md
│   ├── issue-fixer.md
│   ├── single-fix-agent.md
│   ├── review-report-writer.md
│   ├── task-explorer.md
│   └── task-architect.md
│
├── skills/                          # 12 SKILL.md (переписаны под pi)
│   ├── bootstrap/SKILL.md
│   │   └── reference/              # Справочники (переносятся как есть)
│   │       ├── project-md-template.md      # бывш. claude-md-template.md
│   │       ├── hooks-patterns.md
│   │       ├── mcp-servers.md
│   │       ├── quality-criteria.md
│   │       └── update-guidelines.md
│   ├── do/SKILL.md
│   │   └── reference/
│   ├── explore/SKILL.md
│   │   └── reference/
│   ├── fix/SKILL.md
│   │   └── reference/
│   ├── gca/SKILL.md
│   │   └── reference/
│   ├── gp/SKILL.md
│   ├── gst/SKILL.md
│   ├── hi/SKILL.md
│   ├── plan/SKILL.md
│   │   └── reference/
│   │   └── examples/
│   ├── pr/SKILL.md
│   │   └── reference/
│   ├── review/SKILL.md
│   │   └── reference/
│   └── task/SKILL.md
│       └── reference/
│       └── examples/
│
├── extensions/                      # pi-расширения
│   └── yoke-notify.ts               # Уведомления (замена hooks/notify.sh)
│
├── docs/                            # Документация скилов
│   ├── task.md
│   ├── plan.md
│   ├── do.md
│   ├── review.md
│   ├── gca.md
│   ├── gp.md
│   ├── pr.md
│   ├── gst.md
│   ├── fix.md
│   ├── explore.md
│   ├── bootstrap.md
│   ├── hi.md
│   └── notify.md
│
├── yoke.png                         # Логотип
│
└── scripts/
    └── validate.ts                   # Валидация пакета
```

### Ключевые отличия от оригинального yoke

| Что | yoke (Claude Code) | yoke-pi (pi) |
|---|---|---|
| Агенты | `skills/*/agents/*.md` (внутри скиллов) | `agents/*.md` (корень, единый каталог) |
| SKILL.md | Диспатчит через `Agent tool` | Диспатчит через `subagent()` |
| Q&A | `AskUserQuestion` | `ask_user()` |
| Аргументы | `$ARGUMENTS` | Текст после `/skill:name` |
| Путь к корню | `${CLAUDE_PLUGIN_ROOT}` | Относительные пути / имена агентов |
| Контекст проекта | `.claude/yoke-context.md` | `.pi/yoke-context.md` |
| Правила проекта | `CLAUDE.md` | `AGENTS.md` |
| Плагин-файл | `.claude-plugin/plugin.json` | `package.json` (pi key) |
| Манифест | `.claude-plugin/marketplace.json` | `package.json` (pi key) |
| Уведомления | `hooks/hooks.json` + `lib/notify.sh` | `extensions/yoke-notify.ts` |
| Прогресс | `TodoWrite` | Markdown-чеклисты + subagent progress |
| Шаблоны | `{{PLACEHOLDER}}` оркестратором | Контекст через `task:` строку |
| Неймспейс | `/yoke:<name>` | `/skill:<name>` (или `/skill:yoke-<name>` при конфликте) |
| Locale skills | `.claude/skills/` | `.pi/skills/` |

---

## 3. Фаза 0: Подготовка репозитория

### 0.1. Создать репозиторий

```bash
# Клонировать оригинал как отправную точку
git clone https://github.com/yokeloop/yoke.git yoke-pi
cd yoke-pi

# Переписать историю, чтобы не тянуть мусор
# Или начать чистый репозиторий и скопировать нужные файлы
```

### 0.2. Удалить Claude Code-специфичные файлы

```bash
rm -rf .claude-plugin/
rm -rf .claude/
rm -rf hooks/
rm -f  lib/notify.sh
rm -rf docs/ai/          # Примеры артефактов — не нужны в репо
```

### 0.3. Создать package.json

```json
{
  "name": "yoke-pi",
  "version": "1.0.0",
  "description": "A marketplace of skills for pi dev — task, plan, do, review, gca, gp, pr, gst, fix, explore, bootstrap, hi",
  "author": { "name": "Heliotic" },
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/yokeloop/yoke-pi.git"
  },
  "keywords": [
    "pi-package",
    "pi",
    "pi-coding-agent",
    "skills",
    "workflow",
    "productivity",
    "yoke"
  ],
  "pi": {
    "extensions": ["./extensions/yoke-notify.ts"],
    "skills": ["./skills"],
    "agents": ["./agents"]
  },
  "scripts": {
    "format": "prettier --write '**/*.{md,json,ts}'",
    "format:check": "prettier --check '**/*.{md,json,ts}'",
    "validate": "tsx scripts/validate.ts"
  },
  "devDependencies": {
    "husky": "^9.1.7",
    "lint-staged": "^15.4.3",
    "prettier": "^3.5.3",
    "tsx": "^4.19.0",
    "@mariozechner/pi-coding-agent": "*",
    "@sinclair/typebox": "*"
  },
  "lint-staged": {
    "*.{md,json,ts}": "prettier --write"
  },
  "peerDependencies": {
    "@mariozechner/pi-coding-agent": "*"
  },
  "files": [
    "agents/",
    "skills/",
    "extensions/",
    "docs/",
    "README.md",
    "LICENSE",
    "AGENTS.md",
    "yoke.png"
  ]
}
```

### 0.4. Создать .gitignore

```
node_modules/
.yoke/
.worktrees/
.config/wt.toml*
.pi/
```

### 0.5. Создать AGENTS.md (вместо CLAUDE.md)

```markdown
# AGENTS.md

## Project

**yoke-pi** — a marketplace of skills for pi dev, adapted from [yokeloop/yoke](https://github.com/yokeloop/yoke).

## Architecture

```
agents/               # Subagent definitions — discovered by pi-subagents
skills/               # Skills — discovered by pi skill system
extensions/           # pi extensions (yoke-notify)
docs/                 # Per-skill documentation
```

## Key differences from yoke (Claude Code)

- **Agents** are in `agents/` root, discovered by pi-subagents by name
- **Skills** use `subagent()` instead of Agent tool, `ask_user()` instead of AskUserQuestion
- **Project context** is `.pi/yoke-context.md` instead of `.claude/yoke-context.md`
- **Notifications** use pi extensions instead of hooks

## Skills

(Same list as original yoke — task, plan, do, review, etc.)

## Conventions

- Content language: English by default. Skills adapt to the input language.
- Files and directories: kebab-case
- Versioning: semver in package.json
- SKILL.md frontmatter: `name` (identifier, kebab-case), `description` (when to activate)
```

### 0.6. Настроить husky и форматирование

Скопировать `.husky/pre-commit`, `.prettierrc.json`, `.prettierignore`, `.editorconfig` из оригинала.

---

## 4. Фаза 1: Инфраструктура и пакеты

### 1.1. Зависимости pi

В `.pi/settings.json` (проектный) или `~/.pi/agent/settings.json` (глобальный):

```json
{
  "packages": [
    "npm:pi-subagents",
    "npm:pi-ask-user",
    "npm:pi-intercom"
  ]
}
```

Эти пакеты устанавливаются пользователем при установке yoke-pi. В README будет инструкция.

### 1.2. Тестовая установка

```bash
# Установить зависимости
pi install npm:pi-subagents
pi install npm:pi-ask-user
pi install npm:pi-intercom

# Запустить yoke-pi локально
pi --skill-dir ./skills --agents-dir ./agents
```

---

## 5. Фаза 2: Агенты — единый источник правды

Все 37 агентов переносятся в корневой каталог `agents/`. Каждый агент переписывается под формат pi-subagents.

### 5.1. Каталог `agents/`

Почему в корне, а не внутри скилов:

1. pi-subagents ищет агентов в `.pi/agents/` и `agents/` — единый каталог удобнее
2. Агенты используются несколькими скиллами (task-executor из do и fix)
3. При установке как npm-пакет, `agents/` разворачивается в проект

**Альтернатива**: положить агентов в `.pi/agents/` внутри проекта — но тогда они не включаются в npm-пакет автоматически. Рекомендуется `agents/` в корне, а `package.json > pi.agents` указывает на него.

### 5.2. Формат агента

Каждый `agents/<name>.md` переписывается с новым frontmatter:

**Было (Claude Code):**
```yaml
---
name: stack-detector
description: >-
  Detects the tech stack of the project: languages, frameworks, build tools,
  package managers, config files.
tools: Bash, Glob, Read
model: haiku
color: cyan
---
```

**Стало (Pi):**
```yaml
---
name: stack-detector
description: >-
  Detects the tech stack of the project: languages, frameworks, build tools,
  package managers, config files.
tools: bash, find, read, ls
model: anthropic/claude-haiku-4-5
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
output: context.md
defaultProgress: true
---
```

### 5.3. Полная таблица переименования и маппинга агентов

#### Переименования

| Старое имя | Новое имя | Причина |
|---|---|---|
| `claude-md-generator` | `project-md-generator` | Не привязано к Claude Code |

#### Маппинг инструментов (для всех агентов)

| Claude Code | Pi | Убрать |
|---|---|---|
| `Read` | `read` | — |
| `Write` | `write` | — |
| `Edit` | `edit` | — |
| `Bash` | `bash` | — |
| `Glob` | `find` | — |
| `Grep` | `grep` | — |
| `LS` | `ls` | — |
| `NotebookRead` | — | ✗ |
| `WebFetch` | — | ✗ (или `fetch_content` через pi-web-access) |
| `WebSearch` | — | ✗ (или `web_search` через pi-web-access) |
| `TodoWrite` | — | ✗ |
| `KillShell` | — | ✗ |
| `BashOutput` | — | ✗ |

#### Маппинг моделей

| Claude Code | Pi |
|---|---|
| `haiku` | `anthropic/claude-haiku-4-5` |
| `sonnet` | `anthropic/claude-sonnet-4` |
| `opus` | `anthropic/claude-opus-4` |

#### Pi-специфичные поля (добавляются ко всем агентам)

| Поле | Значение | Примечание |
|---|---|---|
| `systemPromptMode` | `replace` | Агент получает чистый промпт |
| `inheritProjectContext` | `true` | Наследует AGENTS.md, .pi/settings |
| `inheritSkills` | `false` | Не наследует глобальные скилы |
| `output` | `context.md` | Где писать результат |
| `defaultProgress` | `true` | Вести progress.md |

### 5.4. Изменения в теле промптов агентов

1. **Убрать `TodoWrite`** — все упоминания удалить
2. **Убрать `{{PLACEHOLDER}}`** — заменить на инструкции «Контекст передан через task»
3. **Убрать `Read ${CLAUDE_PLUGIN_ROOT}/...`** — заменить на «Читай файлы из task-аргумента»
4. **`.claude/yoke-context.md`** → `.pi/yoke-context.md`
5. **`CLAUDE.md`** → `AGENTS.md`
6. **Убрать `NotebookRead`, `KillShell`, `BashOutput`** из списка разрешённых действий
7. **Убрать `color:` из frontmatter**

### 5.5. Пример переписанного агента

**`agents/stack-detector.md`:**

```markdown
---
name: stack-detector
description: >-
  Detects the tech stack of the project: languages, frameworks, build tools,
  package managers, config files.
tools: bash, find, read, ls
model: anthropic/claude-haiku-4-5
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
output: context.md
defaultProgress: true
---

# Stack Detector

Detects the technology stack of the project.

## Process

1. **Package manifests** — check for `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `pom.xml`, `build.gradle`, etc.
2. **Config files** — check for `.eslintrc`, `tsconfig.json`, `Dockerfile`, `docker-compose.yml`, CI configs
3. **Lock files** — check for `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
4. **Source patterns** — glob for .ts, .py, .go, .java, .rb, .rs, etc.
5. **Dev tools** — check for `Makefile`, `justfile`, `Taskfile.yml`

Run each check. On command error — record it and continue.

## Structured Output

Return the data strictly in this format:

```yaml
PATTERN: <monorepo | monolith | microservices | plugin | cli | static-site | flat>
KEY_DIRS:
  - <dir> — <purpose>
  ...
ENTRY_POINTS:
  - <path> — <type>
  ...
LANGUAGES:
  - <language>: <presence indicator>
  ...
FRAMEWORKS:
  - <framework>: <version if detectable>
  ...
BUILD_TOOLS:
  - <tool>: <config file>
  ...
PACKAGE_MANAGERS:
  - <manager>: <lock file>
  ...
TEST_FRAMEWORKS:
  - <framework>: <config>
  ...
ENV_FILES:
  - <filename>: <purpose>
  ...
```

## Rules

- Read-only. Do not modify the repository.
- Command error — record it and continue.
- Return data. The orchestrator makes decisions.
```

### 5.6. Список всех 37 агентов для портирования

| # | Агент | Строк | Скилл | Инструменты CC | Инструменты Pi | Модель Pi | Сложность |
|---|---|---|---|---|---|---|---|
| 1 | stack-detector | 104 | bootstrap | Bash, Glob, Read | bash, find, read, ls | haiku-4-5 | лёгкая |
| 2 | architecture-mapper | 116 | bootstrap | Glob, Grep, Read, Bash | find, grep, read, bash, ls | sonnet-4 | лёгкая |
| 3 | convention-scanner | 110 | bootstrap | Glob, Grep, Read | find, grep, read, ls | sonnet-4 | лёгкая |
| 4 | validation-scanner | 92 | bootstrap | Bash, Glob, Read | bash, find, read, ls | haiku-4-5 | лёгкая |
| 5 | existing-rules-detector | 108 | bootstrap | Bash, Read, Glob | bash, read, find, ls | haiku-4-5 | лёгкая |
| 6 | domain-analyzer | 213 | bootstrap | Glob, Grep, Read, Bash | find, grep, read, bash, ls | sonnet-4 | средняя |
| 7 | project-md-generator | 104 | bootstrap | Read, Write, Edit, Glob | read, write, edit, find, ls | sonnet-4 | лёгкая |
| 8 | yoke-context-generator | 102 | bootstrap | Read, Write, Bash, Glob | read, write, bash, find, ls | haiku-4-5 | лёгкая |
| 9 | automation-recommender | 65 | bootstrap | Read | read | haiku-4-5 | лёгкая |
| 10 | bootstrap-verifier | 97 | bootstrap | Read, Bash, Glob | read, bash, find, ls | sonnet-4 | лёгкая |
| 11 | task-executor | 190 | do | Read, Write, Edit, Bash, Glob, Grep, LS, NotebookRead, WebFetch, TodoWrite | read, write, edit, bash, find, grep, ls | opus-4 | средняя |
| 12 | spec-reviewer | 59 | do | Read, Glob, Grep, LS | read, find, grep, ls | sonnet-4 | лёгкая |
| 13 | quality-reviewer | 75 | do | Read, Glob, Grep, LS, Bash | read, find, grep, ls, bash | sonnet-4 | лёгкая |
| 14 | code-polisher | 67 | do | Read, Write, Edit, Bash, Glob, Grep, LS | read, write, edit, bash, find, grep, ls | opus-4 | лёгкая |
| 15 | validator | 112 | do | Read, Edit, Bash, Glob, Grep, LS | read, edit, bash, find, grep, ls | haiku-4-5 | средняя |
| 16 | formatter | 83 | do | Read, Bash, Glob, Grep, LS | read, bash, find, grep, ls | haiku-4-5 | лёгкая |
| 17 | doc-updater | 87 | do | Read, Write, Edit, Bash, Glob, Grep, LS | read, write, edit, bash, find, grep, ls | sonnet-4 | лёгкая |
| 18 | report-writer | 56 | do | Read, Write, Bash, Glob, LS | read, write, bash, find, ls | haiku-4-5 | лёгкая |
| 19 | explore-agent | 100 | explore | Glob, Grep, LS, Read, Bash, WebSearch, WebFetch | find, grep, ls, read, bash | sonnet-4 | средняя |
| 20 | explore-log-writer | 87 | explore | Read, Write, Edit, Bash | read, write, edit, bash | haiku-4-5 | лёгкая |
| 21 | fix-context-collector | 130 | fix | Bash, Glob, LS | bash, find, ls | haiku-4-5 | средняя |
| 22 | fix-investigator | 86 | fix | Glob, Grep, LS, Read, Bash | find, grep, ls, read, bash | sonnet-4 | лёгкая |
| 23 | fix-log-writer | 95 | fix | Read, Write, Edit, Bash | read, write, edit, bash | haiku-4-5 | лёгкая |
| 24 | git-data-collector | 195 | gst | Bash | bash | haiku-4-5 | средняя |
| 25 | git-pre-checker | 150 | gp | Bash | bash | haiku-4-5 | средняя |
| 26 | git-pusher | 109 | gp | Bash | bash | haiku-4-5 | лёгкая |
| 27 | plan-explorer | 108 | plan | Glob, Grep, LS, Read, ✗4 | find, grep, ls, read | sonnet-4 | средняя |
| 28 | plan-designer | 118 | plan | Glob, Grep, LS, Read, ✗4 | find, grep, ls, read | opus-4 | средняя |
| 29 | plan-reviewer | 78 | plan | Glob, Grep, LS, Read, ✗1 | find, grep, ls, read | sonnet-4 | лёгкая |
| 30 | pr-data-collector | 175 | pr | Bash, Read, Glob | bash, read, find | haiku-4-5 | средняя |
| 31 | pr-body-generator | 103 | pr | Read | read | sonnet-4 | лёгкая |
| 32 | code-reviewer | 118 | review | Read, Bash, Glob, Grep | read, bash, find, grep | sonnet-4 | средняя |
| 33 | issue-fixer | 67 | review | Read, Bash, Glob, Grep | read, bash, find, grep | sonnet-4 | лёгкая |
| 34 | single-fix-agent | 49 | review | Read, Edit, Bash, Glob, Grep, LS | read, edit, bash, find, grep, ls | opus-4 | лёгкая |
| 35 | review-report-writer | 84 | review | Read, Write, Bash, Glob, Grep | read, write, bash, find, grep | sonnet-4 | лёгкая |
| 36 | task-explorer | 62 | task | Glob, Grep, LS, Read, ✗4 | find, grep, ls, read | sonnet-4 | лёгкая |
| 37 | task-architect | 41 | task | Glob, Grep, LS, Read, ✗4 | find, grep, ls, read | opus-4 | лёгкая |

✗ = исключены: NotebookRead, WebFetch, WebSearch, TodoWrite, KillShell, BashOutput

---

## 6. Фаза 3: SKILL.md — универсальные оркестраторы

### 6.1. Принципы переписки SKILL.md

1. **Frontmatter не меняется** — `name` и `description` остаются теми же (pi skill spec использует тот же формат Agent Skills)
2. **Agent tool → `subagent()`** — все dispatch'и переписаны
3. **AskUserQuestion → `ask_user()`** — все Q&A переписаны
4. **`$ARGUMENTS` → инструкция** — «The user's input follows the skill name»
5. **`${CLAUDE_PLUGIN_ROOT}` → имена агентов** — `subagent({ agent: "stack-detector" })` вместо `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap/agents/stack-detector.md`
6. **`TodoWrite` → markdown-чеклист** — прогресс отслеживается текстом
7. **`{{PLACEHOLDER}}` → контекст через `task:`** — оркестратор формирует строку с данными
8. **`.claude/yoke-context.md` → `.pi/yoke-context.md`**
9. **`CLAUDE.md` → `AGENTS.md`**
10. **Path-ссылки на reference/ — остаются относительными** — `reference/commit-convention.md` работает в обеих средах

### 6.2. Паттерны переписки

#### Паттерн: Dispatch одного агента

```markdown
# Было (Claude Code)
Run `git-data-collector` via the Agent tool:
- Agent: `${CLAUDE_PLUGIN_ROOT}/skills/gst/agents/git-data-collector.md`
- Prompt: "Collect data on the current git repository state and produce a report"

# Стало (Pi)
Run `git-data-collector` via subagent:
subagent({ agent: "git-data-collector", task: "Collect data on the current git repository state and produce a report" })
```

#### Паттерн: Параллельный dispatch

```markdown
# Было (Claude Code)
Dispatch 6 agents **in parallel** via the Agent tool (6 calls at once):
1. **stack-detector** (haiku) — read `agents/stack-detector.md`, pass the prompt.
2. **architecture-mapper** (sonnet) — read `agents/architecture-mapper.md`, pass the prompt.
...

# Стало (Pi)
Collect project information in parallel:
subagent({ tasks: [
  { agent: "stack-detector", task: "Detect the tech stack..." },
  { agent: "architecture-mapper", task: "Map the architecture..." },
  { agent: "convention-scanner", task: "Scan conventions..." },
  { agent: "validation-scanner", task: "Scan validation..." },
  { agent: "existing-rules-detector", task: "Detect existing rules..." },
  { agent: "domain-analyzer", task: "Analyze the domain..." }
], concurrency: 6 })
```

#### Паттерн: Цепочка

```markdown
# Было (Claude Code)
Phase 6: Run sub-agents sequentially.
1. spec-reviewer → read `agents/spec-reviewer.md`, dispatch.
2. quality-reviewer → read `agents/quality-reviewer.md`, dispatch.
3. code-polisher → read `agents/code-polisher.md`, dispatch.
4. validator → read `agents/validator.md`, dispatch.
5. doc-updater → read `agents/doc-updater.md`, dispatch.
6. formatter → read `agents/formatter.md`, dispatch.

# Стало (Pi)
Run the review and polish chain:
subagent({ chain: [
  { agent: "spec-reviewer", task: "Verify that the implementation matches the spec from {previous}" },
  { agent: "quality-reviewer", task: "Check code quality from {previous}" },
  { agent: "code-polisher", task: "Polish code from {previous}" },
  { agent: "validator", task: "Run validation from {previous}" },
  { agent: "doc-updater", task: "Update documentation from {previous}" },
  { agent: "formatter", task: "Format changed files from {previous}" }
] })
```

#### Паттерн: AskUserQuestion

```markdown
# Было (Claude Code)
AskUserQuestion with 3 options:
1. Add exception `.claude/yoke-context.md` to .gitignore — commit both files
2. Commit only `CLAUDE.md` — skip yoke-context
3. Cancel — tell the user and exit

# Стало (Pi)
ask_user({
  question: "How should we handle the generated files in git?",
  context: "CLAUDE.md and yoke-context.md have been created. .claude/ may be in .gitignore.",
  options: [
    { title: "Add .pi/yoke-context.md exception to .gitignore", description: "Commit both files" },
    { title: "Commit only AGENTS.md", description: "Skip yoke-context" },
    { title: "Cancel", description: "Don't commit anything" }
  ],
  allowFreeform: true
})
```

#### Паттерн: Переменные в task

```markdown
# Было (Claude Code)
Dispatch `task-executor` with:
- TASK_WHAT: {{TASK_WHAT}}
- TASK_HOW: {{TASK_HOW}}
- TASK_FILES: {{TASK_FILES}}

# Стало (Pi)
subagent({
  agent: "task-executor",
  task: `Execute the following task:

What: ${TASK_WHAT}

How: ${TASK_HOW}

Files to create/change: ${TASK_FILES}

Verify: ${TASK_VERIFY}

If the file .pi/yoke-context.md exists — read it first.`
})
```

### 6.3. Переименования в reference/

| Файл | Старое имя | Новое имя |
|---|---|---|
| bootstrap/reference/ | `claude-md-template.md` | `project-md-template.md` |
| bootstrap/reference/ | `hooks-patterns.md` | Переписать: CC hooks → pi extensions |
| bootstrap/SKILL.md | Ссылки на `.claude/` | `.pi/` |

---

## 7. Фаза 4: Портирование скилов — по порядку сложности

### 7.1. Очерёдность

| # | Скилл | Сложность | Агентов | Приоритет | Типичные изменения |
|---|---|---|---|---|---|
| 1 | **hi** | 🟢 | 0 | 1 | Обновить описание скилов, убрать `/yoke:` |
| 2 | **gst** | 🟡 | 1 | 2 | `subagent()` вместо Agent tool |
| 3 | **gca** | 🟡 | 0 | 3 | `ask_user()`, убрать `$ARGUMENTS` |
| 4 | **gp** | 🟡 | 2 | 4 | `subagent()`, убрать `CLAUDE_PLUGIN_ROOT` |
| 5 | **explore** | 🟡 | 2 | 5 | `ask_user()`, `subagent()`, убрать TodoWrite |
| 6 | **pr** | 🟡 | 2 | 6 | `subagent()`, `ask_user()`, убрать `CLAUDE_PLUGIN_ROOT` |
| 7 | **task** | 🟡 | 2 | 7 | `subagent()`, убрать CC-специфичные tools |
| 8 | **plan** | 🔴 | 3 | 8 | `subagent({ chain })`, убрать шаблоны, CC tools |
| 9 | **review** | 🔴 | 4+2 | 9 | Параллельные fix-агенты, cross-skill ссылки |
| 10 | **fix** | 🔴 | 3+3 | 10 | Cross-skill ссылки, `ask_user()`, эскалация |
| 11 | **bootstrap** | 🔴 | 10 | 11 | Параллельный dispatch, `.claude/` → `.pi/`, шаблоны |
| 12 | **do** | 🔴 | 8 | 12 | Chain, review loop, cross-reference на gca |

### 7.2. Детальный план по каждому простому скиллу

#### hi (21 строк) — 15 мин

- Убрать `/yoke:` префиксы → `/skill:`
- Обновить описания скилов (структура pi: `subagent()`, `ask_user()`)

#### gst (21 строк) — 30 мин

- `Agent tool` dispatch → `subagent({ agent: "git-data-collector", task: "..." })`
- Убрать `${CLAUDE_PLUGIN_ROOT}/skills/gst/agents/git-data-collector.md`

#### gca (128 строк) — 1 час

- `AskUserQuestion` → `ask_user()` (3 вхождения)
- `$ARGUMENTS` → инструкция про аргументы
- `TodoWrite` → убрать
- `reference/` — оставить как есть

#### gp (156 строк) — 1.5 часа

- `Agent tool` dispatch → `subagent()` для 2 агентов
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов
- `$ARGUMENTS` → инструкция

#### explore (154 строки) — 2 часа

- `Agent tool` dispatch → `subagent()` для 2 агентов
- `AskUserQuestion` → `ask_user()` (3 вхождения)
- `$ARGUMENTS` → инструкция
- `TodoWrite` → markdown-чеклист

#### pr (157 строк) — 2 часа

- `Agent tool` dispatch → `subagent()` для 2 агентов
- `AskUserQuestion` → `ask_user()`
- `$ARGUMENTS` → инструкция
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов

#### task (286 строк) — 2.5 часа

- `Agent tool` dispatch → `subagent()` для 2 агентов
- `AskUserQuestion` → `ask_user()`
- `$ARGUMENTS` → инструкция
- Убрать KillShell, BashOutput, WebSearch, WebFetch из ссылок

### 7.3. Детальный план по сложным скиллам

#### plan (315 строк) — 3 часа

- 3 агента → `subagent({ chain: [...] })`
- Убрать `{{PLACEHOLDER}}` — оркестратор собирает контекст для `task:`
- Убрать KillShell, BashOutput, WebSearch, WebFetch
- `AskUserQuestion` → `ask_user()`
- `TodoWrite` → markdown-чеклист

#### review (187 строк) — 3 часа

- 4 собственных + 2 cross-skill агента → `subagent()` по имени
- Параллельные fix-агенты → `subagent({ tasks: [...] })`
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов
- `AskUserQuestion` → `ask_user()`

#### fix (287 строк) — 3.5 часа

- 3 собственных + 3 cross-skill агента → `subagent()` по имени
- `AskUserQuestion` → `ask_user()`
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов
- `TodoWrite` → убрать
- `notify.sh` → `ask_user()` + markdown note

#### bootstrap (356 строк) — 4 часа

- 10 агентов → параллельный dispatch `subagent({ tasks: [...], concurrency: 6 })`
- `{{PLACEHOLDER}}` шаблоны → контекст через `task:` строки
- `AskUserQuestion` → `ask_user()`
- `TodoWrite` → markdown-чеклист
- `.claude/` → `.pi/`
- `${CLAUDE_PLUGIN_ROOT}` → имена агентов
- `notify.sh` → pi extension

#### do (312 строк) — 4 часа

- 8 агентов → `subagent({ chain: [...] })`
- Параллельные `task-executor` → `subagent({ tasks: [...] })`
- `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` → агент читает файл напрямую
- `TodoWrite` → убрать
- `notify.sh` → pi extension
- `{{PLACEHOLDER}}` → контекст через `task:` строки

---

## 8. Фаза 5: Расширения и уведомления

### 8.1. `extensions/yoke-notify.ts`

Замена `hooks/hooks.json` + `lib/notify.sh` + `hooks/notify.sh`.

```typescript
// extensions/yoke-notify.ts
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Регистрируем кастомный инструмент для уведомлений
  pi.registerTool({
    name: "yoke_notify",
    label: "Yoke Notification",
    description:
      "Send a notification about a yoke skill event. Use for ACTION_REQUIRED, STAGE_COMPLETE, and ALERT events.",
    parameters: {
      type: "object",
      properties: {
        type: { type: "string", enum: ["ACTION_REQUIRED", "STAGE_COMPLETE", "ALERT"] },
        skill: { type: "string", description: "Skill name" },
        phase: { type: "string", description: "Phase name" },
        slug: { type: "string", description: "Task slug" },
        title: { type: "string", description: "Notification title" },
        body: { type: "string", description: "Notification body" },
      },
      required: ["type", "skill", "title"],
    },
    async execute(_toolCallId, params) {
      const { type, skill, phase, slug, title, body } = params as any;

      // Формируем текстовое уведомление
      const emoji = type === "ACTION_REQUIRED" ? "⏸" : type === "STAGE_COMPLETE" ? "✅" : "⚠️";
      const message = `${emoji} ${type} — ${skill}${phase ? ` / ${phase}` : ""}: ${title}${body ? `\n${body}` : ""}`;

      return {
        content: [{ type: "text", text: `Notification sent: ${message}` }],
      };
    },
  });
}
```

**Дальнейшее расширение:** При установленном `pi-intercom`, уведомления можно отправлять через intercom в родительскую сессию.

### 8.2. `.pi/yoke-context.md` вместо `.claude/yoke-context.md`

Агент `yoke-context-generator` и `bootstrap` SKILL.md обновляются:
- Путь: `.pi/yoke-context.md` вместо `.claude/yoke-context.md`
- Правила проекта: `AGENTS.md` вместо `CLAUDE.md`
- Bootstrap генерирует `AGENTS.md` вместо `CLAUDE.md`

### 8.3. `reference/hooks-patterns.md` → `reference/pi-extensions.md`

Файл `bootstrap/reference/hooks-patterns.md` переписывается под pi extensions:

```markdown
# Pi Extensions for yoke

## Notification extension

yoke-pi ships a `yoke_notify` tool that skills call to surface events.

### Integration with pi-intercom

When pi-intercom is installed and a subagent needs to notify the orchestrator:
use `intercom({ action: "send", to: "<target>", message: "..." })`.

### Integration with pi-subagents

Skill SKILL.md files reference subagents by name. pi-subagents discovers agents
from the `agents/` directory and `.pi/agents/` automatically.
```

---

## 9. Фаза 6: Документация и CI

### 9.1. README.md

Полная переработка README:
- Убрать все `/yoke:` префиксы → `/skill:`
- Убрать `{CLAUDE_PLUGIN_ROOT}` ссылки
- Добавить секцию установки pi
- Добавить список зависимостей (pi-subagents, pi-ask-user, pi-intercom)
- Обновить примеры команд
- Обновить структуру каталогов

### 9.2. docs/*.md

Обновить 12 файлов документации скилов:
- `/yoke:<name>` → `/skill:<name>`
- Agent tool → subagent()
- AskUserQuestion → ask_user()
- Официальные имена моделей
- Примеры команд pi

### 9.3. CI / валидация

`scripts/validate.ts`:
```typescript
// Проверить:
// 1. Все SKILL.md имеют корректный frontmatter (name, description)
// 2. Все агенты в agents/ имеют корректный frontmatter pi-subagents
// 3. Все агенты, на которые ссылаются SKILL.md, существуют в agents/
// 4. Все reference/ файлы, на которые ссылаются SKILL.md, существуют
// 5. package.json валиден
```

### 9.4. Husky + prettier

Перенести из оригинала: `.husky/pre-commit`, `.prettierrc.json`, `.prettierignore`

---

## 10. Фаза 7: Тестирование и полировка

### 10.1. Smoke-тест каждого скилла

Для каждого скилла — запустить в тестовом проекте:

| Скилл | Тестовая команда | Ожидаемый результат |
|---|---|---|
| hi | `/skill:hi` | Выводит список скилов |
| gst | `/skill:gst` | Показывает статус репозитория |
| gca | Создать файл, `/skill:gca` | Коммит с группировкой |
| gp | `/skill:gp` | Пуш с отчётом |
| pr | `/skill:pr --draft` | Создаёт draft PR |
| explore | `/skill:explore how does auth work` | Исследование с логом |
| task | `/skill:task add dark mode` | Файл task.md |
| plan | `/skill:plan docs/ai/...task.md` | Файл plan.md |
| do | `/skill:do docs/ai/...plan.md` | Реализация + отчёт |
| fix | `/skill:fix fix validation bug` | Фикс + лог |
| review | `/skill:review` | Файл review.md |
| bootstrap | `/skill:bootstrap` | AGENTS.md + context |

### 10.2. Критерии проверки

1. **Все агенты обнаружены** — `subagent({ action: "list" })` показывает всех 37
2. **Все скилы активируются** — `/skill:<name>` работает для каждого
3. **ask_user работает** — Q&A отображается в TUI
4. **Параллельный dispatch работает** — bootstrap запускает 6 агентов одновременно
5. **Цепочки работают** — do последовательно прогоняет review → polish → validate
6. **Контекст проекта читается** — `.pi/yoke-context.md` читается агентами
7. **Уведомления доставляются** — `yoke_notify` выводит сообщения

---

## 11. Критерии приёмки

- [ ] Все 12 SKILL.md переписаны под pi
- [ ] Все 37 агентов переписаны под pi-subagents frontmatter
- [ ] `pi install npm:yoke-pi` устанавливается без ошибок
- [ ] `pi --skill-dir ./skills` загружает все скилы
- [ ] `subagent({ action: "list" })` показывает 37 агентов
- [ ] Каждый скилл протестирован в pi dev
- [ ] README.md обновлён
- [ ] docs/*.md обновлён
- [ ] CI (format:check + validate) проходит
- [ ] Нет ссылок на Claude Code, `${CLAUDE_PLUGIN_ROOT}`, `$ARGUMENTS`, `AskUserQuestion`, `Agent tool`

---

## 12. Риски

| Риск | Вероятность | Влияние | Митигация |
|---|---|---|---|
| Pi-subagents не поддерживает нужную модель | Низкая | Среднее | Использовать fallbackModels в frontmatter |
| ask_user не работает в неинтерактивном режиме | Низкая | Низкое | Есть fallback (текстовый вывод) |
| Параллельный dispatch не работает как ожидается | Среднее | Высокое | Тестировать concurrency, при проблемах — последовательный dispatch |
| Агенты доступны не по имени, а по пути | Низкая | Среднее | Проверить discovery: `subagent({ action: "list" })` |
| Шаблоны `{{PLACEHOLDER}}` теряются при передаче через `task:` | Среднее | Среднее | Тестировать передачу длинного контекста; при проблемах — записывать во временный файл + `reads:` |
| `.pi/agents/` не подхватывается из npm-пакета | Среднее | Высокое | Проверить pi package discovery; при проблемах — ручная установка агентов |
| yoke-pi конфликтует с builtin-агентами pi-subagents | Низкая | Среднее | Проверить уникальность имён; при конфликтах — добавить префикс `yoke-` |

---

## 13. Оценка трудозатрат

### По фазам

| Фаза | Описание | Оценка |
|---|---|---|
| 0 | Подготовка репозитория | 0.5 дня |
| 1 | Инфраструктура и пакеты | 0.5 дня |
| 2 | Агенты (37 файлов) | 2-3 дня |
| 3 | SKILL.md — простые (6 штук) | 1-2 дня |
| 4 | SKILL.md — средние (1 штука) | 1 день |
| 5 | SKILL.md — сложные (5 штук) | 3-4 дня |
| 5 | Расширения и уведомления | 1 день |
| 6 | Документация и CI | 1 день |
| 7 | Тестирование и полировка | 2-3 дня |
| **Итого** | | **12-16 дней** |

### По типам файлов

| Тип | Количество | Оценка |
|---|---|---|
| Агенты (agents/*.md) | 37 файлов | 2-3 дня (механическая замена frontmatter + очистка тела) |
| SKILL.md | 12 файлов | 4-6 дней (перепись логики оркестрации) |
| Расширения (extensions/*.ts) | 1 файл | 0.5 дня |
| Скрипты (scripts/*.ts) | 1 файл | 0.5 дня |
| package.json, AGENTS.md, .gitignore | 3 файла | 0.5 дня |
| README.md | 1 файл | 0.5 дня |
| docs/*.md | 12 файлов | 1 день |
| reference/ (модификация) | ~5 файлов | 0.5 дня |
| **Итого** | ~72 файла | **12-16 дней** |

---

## Приложение A: Полный файловый лист миграции

### Удалить (Claude Code-специфичное)

```
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
.claude/settings.json
.claude/skills/yoke-create/SKILL.md
.claude/skills/yoke-release/SKILL.md
hooks/hooks.json
hooks/notify.sh
lib/notify.sh
commands/                        # (пустая директория)
CLAUDE.md
```

### Создать заново

```
package.json                      # npm-пакет yoke-pi с pi config
AGENTS.md                         # Инструкции для pi
.gitignore                        # Обновлённый
.pi/settings.json                 # (для локальной разработки, не в пакете)
extensions/yoke-notify.ts         # Pi extension для уведомлений
scripts/validate.ts               # Валидация пакета
```

### Переписать полностью (37 агентов)

```
agents/stack-detector.md
agents/architecture-mapper.md
agents/convention-scanner.md
agents/validation-scanner.md
agents/existing-rules-detector.md
agents/domain-analyzer.md
agents/project-md-generator.md       # бывш. claude-md-generator.md
agents/yoke-context-generator.md
agents/automation-recommender.md
agents/bootstrap-verifier.md
agents/task-executor.md
agents/spec-reviewer.md
agents/quality-reviewer.md
agents/code-polisher.md
agents/validator.md
agents/formatter.md
agents/doc-updater.md
agents/report-writer.md
agents/explore-agent.md
agents/explore-log-writer.md
agents/fix-context-collector.md
agents/fix-investigator.md
agents/fix-log-writer.md
agents/git-data-collector.md
agents/git-pre-checker.md
agents/git-pusher.md
agents/plan-explorer.md
agents/plan-designer.md
agents/plan-reviewer.md
agents/pr-data-collector.md
agents/pr-body-generator.md
agents/code-reviewer.md
agents/issue-fixer.md
agents/single-fix-agent.md
agents/review-report-writer.md
agents/task-explorer.md
agents/task-architect.md
```

### Переписать полностью (12 SKILL.md)

```
skills/bootstrap/SKILL.md
skills/do/SKILL.md
skills/explore/SKILL.md
skills/fix/SKILL.md
skills/gca/SKILL.md
skills/gp/SKILL.md
skills/gst/SKILL.md
skills/hi/SKILL.md
skills/plan/SKILL.md
skills/pr/SKILL.md
skills/review/SKILL.md
skills/task/SKILL.md
```

### Перенести с модификациями (reference/)

```
skills/bootstrap/reference/project-md-template.md     # бывш. claude-md-template.md
skills/bootstrap/reference/hooks-patterns.md          # существенно переписать → pi-extensions.md
skills/bootstrap/reference/mcp-servers.md             # оставить как есть
skills/bootstrap/reference/quality-criteria.md        # оставить как есть
skills/bootstrap/reference/update-guidelines.md       # оставить как есть
skills/do/reference/status-protocol.md                # убрать TodoWrite
skills/do/reference/report-format.md                 # оставить как есть
skills/explore/reference/exploration-log-format.md   # оставить как есть
skills/fix/reference/fix-log-format.md               # оставить как есть
skills/gca/reference/commit-convention.md            # оставить как есть
skills/gca/reference/staging-strategy.md             # оставить как есть
skills/plan/examples/simple-plan.md                   # оставить как есть
skills/plan/examples/complex-plan.md                 # оставить как есть
skills/plan/reference/elements-of-style-rules.md     # оставить как есть
skills/plan/reference/plan-format.md                  # оставить как есть
skills/plan/reference/routing-rules.md               # оставить как есть
skills/pr/reference/pr-body-format.md                # оставить как есть
skills/review/reference/review-format.md             # оставить как есть
skills/task/examples/simple-task.md                   # оставить как есть
skills/task/examples/complex-task.md                 # оставить как есть
skills/task/reference/elements-of-style-rules.md     # оставить как есть
skills/task/reference/frontend-guide.md              # оставить как есть
skills/task/reference/synthesize-guide.md            # оставить как есть
```

### Переписать (документация)

```
README.md
docs/task.md
docs/plan.md
docs/do.md
docs/review.md
docs/gca.md
docs/gp.md
docs/pr.md
docs/gst.md
docs/fix.md
docs/explore.md
docs/bootstrap.md
docs/hi.md
docs/notify.md
```

## Приложение B: Установка yoke-pi конечным пользователем

```bash
# 1. Установить yoke-pi как pi-пакет
pi install npm:yoke-pi

# Или из git:
pi install git:yokeloop/yoke-pi

# 2. Установить зависимости
pi install npm:pi-subagents
pi install npm:pi-ask-user
pi install npm:pi-intercom

# 3. (Опционально) Установить веб-доступ
pi install npm:pi-web-access

# 4. Запустить
cd my-project
pi

# 5. Использовать
> /skill:hi           # обзор скилов
> /skill:bootstrap    # подготовить проект
> /skill:task ...     # определить задачу
> /skill:plan ...     # построить план
> /skill:do ...       # выполнить план
```

## Приложение C: Справочник pi-subagents frontmatter

```yaml
---
name: my-agent                    # 1-64 символов, kebab-case
description: What this agent does  # До 1024 символов
tools: read, write, edit, bash, find, grep, ls
model: anthropic/claude-sonnet-4   # Модель
fallbackModels:                   # Запасные модели
  - openai/gpt-5-mini
  - anthropic/claude-haiku-4-5
thinking: high                    # off, minimal, low, medium, high, xhigh
systemPromptMode: replace          # replace (default) или append
inheritProjectContext: true         # Наследовать AGENTS.md, .pi/settings
inheritSkills: false                # Наследовать каталог скилов
skills: ask-user                   # Инжектировать скилы (через +)
output: context.md                 # Файл вывода по умолчанию
defaultReads: context.md           # Файлы для чтения перед стартом
defaultProgress: true               # Вести progress.md
maxSubagentDepth: 1               # Лимит вложенности суб-агентов
---

Системный промпт агента...
```

## Приложение D: Справочник ask_user API

```json
{
  "question": "Which option?",
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

Ответ:
```json
{ "kind": "selection", "selections": ["Option A"], "comment": null }
```
или
```json
{ "kind": "freeform", "text": "Custom answer..." }
```
или
```json
null  // Пользователь отменил
```

## Приложение E: Справочник subagent() API

```typescript
// Одиночный агент
subagent({ agent: "stack-detector", task: "Detect the tech stack" })

// С выбором модели
subagent({ agent: "task-executor", task: "...", model: "anthropic/claude-opus-4" })

// Параллельный
subagent({
  tasks: [
    { agent: "stack-detector", task: "Detect stack" },
    { agent: "architecture-mapper", task: "Map architecture" }
  ],
  concurrency: 2
})

// Цепочка
subagent({
  chain: [
    { agent: "task-executor", task: "Implement: ..." },
    { agent: "spec-reviewer", task: "Review spec from {previous}" },
    { agent: "validator", task: "Validate from {previous}" }
  ]
})

// Асинхронный
subagent({ agent: "worker", task: "...", async: true })

// Fork context
subagent({ agent: "oracle", task: "Review direction", context: "fork" })

// Управление
subagent({ action: "list" })
subagent({ action: "status" })
subagent({ action: "interrupt", id: "abc123" })
subagent({ action: "doctor" })
```