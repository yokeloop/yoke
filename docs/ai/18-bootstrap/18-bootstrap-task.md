# Скилл /bootstrap — подготовка проекта к sp flow

**Slug:** 18-bootstrap
**Тикет:** https://github.com/projectory-com/sp/issues/18
**Сложность:** complex
**Тип:** general

## Task

Создать скилл `/bootstrap` — одноразовую подготовку проекта к sp flow. Скилл детектирует стек и архитектуру, генерирует или обогащает CLAUDE.md до Grade A, создаёт `.claude/sp-context.md`, формирует рекомендации по hooks и MCP. Обновить 7 агентов: каждый при наличии `sp-context.md` читает его, при отсутствии — работает как прежде.

## Context

### Архитектура области

Плагин sp — маркетплейс скиллов для Claude Code. Каждый скилл живёт в `skills/<name>/` и содержит `SKILL.md` (оркестратор), опциональные `agents/` (sub-agents) и `reference/` (вспомогательные материалы).

Структура скилла:

```
skills/<name>/
  SKILL.md              # оркестратор, YAML frontmatter (name, description)
  agents/<role>.md       # sub-agents, frontmatter (name, description, tools, model, color)
  reference/<file>.md    # шаблоны, правила, гайды
```

Модели по ролям: haiku — сбор данных и write; sonnet — исследование и review; opus — архитектура и реализация.

Внутри скилла пути относительные (`reference/file.md`). Между скиллами — абсолютные: `${CLAUDE_PLUGIN_ROOT}/skills/<name>/reference/file.md`.

### Файлы для создания

**SKILL.md и агенты (15 файлов):**

- `skills/bootstrap/SKILL.md` — оркестратор, 6 фаз (Preflight → Detect → Synthesize → Generate → Verify → Confirm → Commit)
- `skills/bootstrap/agents/stack-detector.md` — haiku, cyan, read-only. Определяет языки, фреймворки, package manager, runtime
- `skills/bootstrap/agents/architecture-mapper.md` — sonnet, yellow, read-only. Строит карту директорий, слоёв, entry points, паттернов
- `skills/bootstrap/agents/convention-scanner.md` — sonnet, yellow, read-only. Извлекает naming, import style, code style из кода
- `skills/bootstrap/agents/validation-scanner.md` — haiku, cyan, read-only. Собирает команды lint/test/build/format из конфигов и скриптов
- `skills/bootstrap/agents/existing-rules-detector.md` — haiku, cyan, read-only. Ищет CLAUDE.md, README, CONTRIBUTING, .cursorrules и оценивает качество
- `skills/bootstrap/agents/claude-md-generator.md` — sonnet, green, write. Создаёт или дополняет CLAUDE.md по шаблону и quality-criteria
- `skills/bootstrap/agents/sp-context-generator.md` — haiku, gray, write. Записывает `.claude/sp-context.md` по шаблону
- `skills/bootstrap/agents/automation-recommender.md` — haiku, cyan, read-only. Формирует рекомендации по hooks и MCP
- `skills/bootstrap/agents/bootstrap-verifier.md` — sonnet, cyan, read-only. Проверяет файлы: секции, пути, команды

**Reference-файлы (5 файлов):**

- `skills/bootstrap/reference/quality-criteria.md` — адаптированная рубрика из claude-md-management (6 критериев, 100 баллов, грейды A-F)
- `skills/bootstrap/reference/claude-md-template.md` — шаблоны CLAUDE.md (minimal, comprehensive, monorepo)
- `skills/bootstrap/reference/update-guidelines.md` — что включать, что исключать, red flags
- `skills/bootstrap/reference/hooks-patterns.md` — паттерны hooks по стекам из claude-code-setup
- `skills/bootstrap/reference/mcp-servers.md` — рекомендованные MCP серверы по типу интеграций

Reference-файлы создать на основе [claude-md-management](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) и [claude-code-setup](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-code-setup).

### Файлы для изменения (обновление 7 агентов)

Каждому агенту добавить "Шаг 0 — Context" — graceful чтение `sp-context.md`:

- `skills/task/agents/task-explorer.md` — перед "1. Обнаружение фичи" (строка 17)
- `skills/task/agents/task-architect.md` — перед "1. Анализ паттернов" (строка 14), расширить существующее чтение CLAUDE.md
- `skills/plan/agents/plan-explorer.md` — перед первым шагом процесса
- `skills/plan/agents/plan-designer.md` — перед первым шагом процесса
- `skills/do/agents/task-executor.md` — перед "Прочитай все файлы из Context" (после "Before You Begin")
- `skills/do/agents/validator.md` — перед валидацией (critical: берёт Validation Commands)
- `skills/do/agents/formatter.md` — перед форматированием (critical: берёт format command)
- `skills/review/agents/review-analyzer.md` — перед анализом (берёт Conventions, Architecture)
- `skills/explore/agents/explore-agent.md` — дополнить строку 37 (уже читает CLAUDE.md, добавить sp-context.md)
- `skills/fix/agents/fix-investigator.md` — дополнить строку 39 (уже читает CLAUDE.md, добавить sp-context.md)

Также обновить:

- `CLAUDE.md` — добавить `/bootstrap` в секцию "Implemented skills"

### Паттерны для повторения

**SKILL.md оркестратор с фазами:** `skills/task/SKILL.md` — 6 фаз с TodoWrite, notify.sh, AskUserQuestion. Повторить структуру: вход, фазы, правила.

**Параллельный dispatch агентов:** `skills/do/SKILL.md` — параллельные группы через Agent tool. Применить в Phase 1 (5 агентов одновременно).

**Read-only агенты:** `skills/explore/agents/explore-agent.md` — tools: `Glob, Grep, LS, Read, Bash, WebSearch, WebFetch`. Без Write и Edit. Применить к 5 detect-агентам и automation-recommender.

**Нотификации:** `bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type TYPE --skill bootstrap --phase PHASE --slug "bootstrap" --title "..." --body "..."`. ACTION_REQUIRED перед AskUserQuestion, STAGE_COMPLETE по завершении.

**Cross-skill ссылки:** `skills/fix/SKILL.md` — `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/task-executor.md`. Применить для ссылки на commit-convention.

**Graceful degradation:** "Если `sp-context.md` существует — прочитай. Иначе — определи контекст самостоятельно."

### Тесты

Тестов нет. Валидация через:

```bash
# Проверить YAML frontmatter
head -1 skills/bootstrap/SKILL.md skills/bootstrap/agents/*.md
# Проверить JSON манифесты
python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('OK')"
# Проверить что reference-файлы существуют
ls skills/bootstrap/reference/
```

## Requirements

1. Создать `skills/bootstrap/SKILL.md` — оркестратор с 6 фазами: Preflight (git-repo, не sp-repo), Detect (5 параллельных read-only агентов), Synthesize (агрегация PROJECT_PROFILE), Generate (claude-md-generator + sp-context-generator + automation-recommender), Verify (проверка файлов и CLAUDE.md quality), Confirm (AskUserQuestion: коммитить / редактировать / отменить), Commit (git add + commit).
2. Создать 10 агентов в `skills/bootstrap/agents/` с корректным frontmatter (name, description, tools, model, color). Read-only агенты — без Write/Edit. Write-агенты (claude-md-generator, sp-context-generator) — с Write/Edit.
3. Создать 5 reference-файлов в `skills/bootstrap/reference/` на основе [claude-md-management](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) и [claude-code-setup](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-code-setup). Адаптировать под bootstrap, не копировать дословно.
4. Phase 0 (Preflight): `git rev-parse --is-inside-work-tree` + убедиться, что `.claude-plugin/plugin.json` отсутствует. При невалидном окружении — abort с сообщением.
5. Phase 1 (Detect): запустить 5 агентов параллельно через Agent tool. Каждый возвращает structured output. Оркестратор ждёт завершения всех пяти перед Synthesize.
6. Phase 2 (Synthesize): оркестратор агрегирует findings в PROJECT_PROFILE (in-memory). Структура: name, languages, frameworks, package_manager, architecture (pattern, layers, entry_points, key_dirs), commands (dev, build, test, lint, format, typecheck), conventions, existing_rules.
7. Phase 3 (Generate): claude-md-generator создаёт или дополняет CLAUDE.md (Edit при существующем, Write при новом). sp-context-generator записывает `.claude/sp-context.md` (всегда Write). automation-recommender формирует текст рекомендаций, файлы не меняет.
8. Phase 4 (Verify): bootstrap-verifier проверяет: файлы существуют, обязательные секции присутствуют, пути из CLAUDE.md валидны, команды валидации запускаются. Цель — Grade A (90+ баллов). При проблемах оркестратор исправляет через Edit.
9. Phase 5 (Confirm): показать сводку (PROJECT_PROFILE, quality score, содержимое файлов, рекомендации). AskUserQuestion: Закоммитить (Recommended) / Просмотреть и отредактировать / Отменить. При редактировании — re-verify, затем Confirm.
10. Phase 6 (Commit): `git add CLAUDE.md .claude/sp-context.md && git commit`. Формат: `chore: bootstrap sp flow context`. Нотификация STAGE_COMPLETE.
11. Обновить 7+ агентов — добавить "Шаг 0 — Context" с graceful чтением `sp-context.md`. Формат: "Если существует — прочитай. Иначе — работай как прежде." Без hard dependency.
12. `/bootstrap` идемпотентен: повторный запуск обновляет файлы, сохраняет пользовательский контент CLAUDE.md. sp-context.md перезаписывается полностью — source of truth остаётся кодовая база.
13. Добавить `/bootstrap` в секцию "Implemented skills" в `CLAUDE.md`.

## Constraints

- `.claude-plugin/plugin.json` и `.claude-plugin/marketplace.json` оставить без изменений.
- claude-md-generator дополняет существующий CLAUDE.md через Edit, сохраняя пользовательский контент. Write — только для нового файла.
- automation-recommender формирует текст рекомендаций для Phase 5, файлы не меняет.
- sp-context.md коммитить (`.claude/sp-context.md`). Если `.claude/` в `.gitignore` — предупредить пользователя в Phase 6.
- Агенты читают sp-context.md при наличии, без него работают как прежде. Hard dependency запрещена.
- `_skills/` (черновики) и `docs/` (кроме `docs/ai/`) оставить без изменений.
- Scope issue #18 — удаление hardcoded toolchain из скиллов вынесено в #54.
- Контент скилла — на русском. task-slug и файлы — английский kebab-case.

## Verification

- `head -1 skills/bootstrap/SKILL.md` → `---` (валидный YAML frontmatter)
- `head -1 skills/bootstrap/agents/*.md` → каждый файл начинается с `---`
- `ls skills/bootstrap/agents/ | wc -l` → 10 агентов
- `ls skills/bootstrap/reference/ | wc -l` → 5 reference-файлов
- `grep -l "sp-context" skills/task/agents/task-explorer.md skills/task/agents/task-architect.md skills/plan/agents/plan-explorer.md skills/plan/agents/plan-designer.md skills/do/agents/task-executor.md skills/do/agents/validator.md skills/do/agents/formatter.md skills/review/agents/review-analyzer.md skills/explore/agents/explore-agent.md skills/fix/agents/fix-investigator.md` → все 10 файлов содержат упоминание sp-context
- `grep "bootstrap" CLAUDE.md` → `/bootstrap` в списке Implemented skills
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('OK')"` → OK (манифест не сломан)
- Повторный запуск `/bootstrap` → обновляет файлы без ошибок, пользовательский контент CLAUDE.md сохранён

## Материалы

- [Issue #18](https://github.com/projectory-com/sp/issues/18) — архитектура, фазы, агенты
- [claude-md-management](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) — рубрика качества CLAUDE.md, шаблоны, guidelines
- [claude-code-setup](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-code-setup) — детекция стека, hooks, MCP
- `skills/task/SKILL.md` — паттерн оркестратора с фазами, notify, commit
- `skills/explore/agents/explore-agent.md` — паттерн read-only агента
- `skills/fix/SKILL.md` — паттерн cross-skill agent reuse
- `skills/gca/reference/commit-convention.md` — конвенция коммитов
