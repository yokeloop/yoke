# Переделать /review: code review + автоматическое исправление

**Slug:** 44-review-with-fixes
**Тикет:** https://github.com/projectory-com/sp/issues/44
**Сложность:** complex
**Тип:** general

## Task

Добавить в `/review` поиск проблем с числовым скорингом, интерактивный выбор scope фиксов, автоматическое исправление через opus-агента и расширенный отчёт с таблицами исправленных и пропущенных проблем.

## Context

### Архитектура области

Текущий `/review` — тонкий оркестратор с одним агентом:

```
SKILL.md (оркестратор, 91 строк)
  └─ review-analyzer.md (sub-agent, 119 строк)
     └─ git log/diff → анализ по 7 измерениям → запись review.md
```

Две точки вызова:
- `/do` Фаза 7 (`skills/do/SKILL.md:283-288`) — `Skill tool с "/sp:review" и аргументом "<SLUG>"`
- `/fix` Фаза 7 (`skills/fix/SKILL.md:249`) — `Skill tool с "/sp:review" и SLUG`

Принимает SLUG как `$ARGUMENTS`. Определяет SLUG из аргумента, текущей ветки или `docs/ai/*/`.

Артефакт: `docs/ai/<SLUG>/<SLUG>-review.md`. Коммит: `TICKET docs(SLUG): add review report`.

### Файлы для изменения

- `skills/review/SKILL.md` — переписать оркестратор (pipeline из 6 фаз)
- `skills/review/agents/review-analyzer.md` — переименовать в `code-reviewer.md`, добавить поиск проблем и скоринг
- `skills/review/agents/issue-fixer.md` — создать агента для исправления проблем (opus)
- `skills/review/agents/review-report-writer.md` — создать агента для расширенного отчёта
- `skills/review/reference/review-format.md` — создать шаблон отчёта с секциями fixed/skipped

### Паттерны для повторения

**Pipeline из /do** (`skills/do/SKILL.md`): Parse → Execute → Polish → Validate → Document → Finalize → Complete. Каждую фазу выполняет sub-agent. Статусы sub-agent'ов обрабатываются по `skills/do/reference/status-protocol.md`.

**Scope guard из /fix** (`skills/fix/SKILL.md:116-127`): при слишком большом числе файлов — предложить escalate.

**AskUserQuestion из /fix** (`skills/fix/SKILL.md:130-134`): уточнения через интерактивные вопросы с вариантами.

**Quality reviewer из /do** (`skills/do/agents/quality-reviewer.md`): классификация Critical/Important/Minor, формат VERDICT + ISSUES + ASSESSMENT.

**Reuse агентов из /do:** `skills/do/agents/validator.md` и `formatter.md` подключаются через `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/` (паттерн из /fix).

**Коммит-конвенция:** `skills/gca/reference/commit-convention.md` — `TICKET type(SLUG): description`.

### Тесты

Тесты отсутствуют. Валидация через `pnpm run format:check`.

## Requirements

1. **Code review агент** (один sonnet) анализирует diff по 7+ категориям: bugs, quality, style, documentation, tests, performance, security. Каждой проблеме присваивает числовой скор 0-100 и классификацию Critical (80-100) / Important (50-79) / Minor (0-49).

2. **Автономный режим** — без остановок между фазами, как /do. Две паузы: AskUserQuestion для выбора scope фиксов и финальный выбор действия.

3. **Интерактивный выбор scope** — после code review показать все проблемы, пользователь выбирает, какие исправлять.

4. **Issue fixer** (opus) исправляет выбранные проблемы за один проход и коммитит результат.

5. **Post-process** — после фиксов запустить validator и formatter (reuse из /do).

6. **Расширенный отчёт** — `<SLUG>-review.md` содержит:
   - Анализ по 7 измерениям (как сейчас)
   - Таблица найденных проблем (severity, score, file:line, description)
   - Таблица исправленных проблем (commit, description)
   - Таблица пропущенных проблем (reason)
   - Рекомендации для PR review

7. **PR-комментарии** — если PR существует, постить неисправленные проблемы как комментарии через `gh api`.

8. **Post-flow awareness** — при наличии `<SLUG>-report.md` (запуск после /do) прочитать spec/quality review results и исключить уже найденные проблемы.

9. **Fix-log awareness** — при наличии `<SLUG>-fixes.md` (запуск после /fix) прочитать и исключить уже исправленное.

10. **Обратная совместимость** — сохранить интерфейс вызова (SLUG как $ARGUMENTS). `/do` и `/fix` вызывают `/review` без изменений.

## Constraints

- `/do` и `/fix` остаются без правок — интерфейс вызова совместим.
- Документация входит в категории code-reviewer — отдельный агент для ревью документации запрещён.
- Один sonnet с полным контекстом diff — haiku для code review запрещён.
- Артефакт `/review` — отдельный файл `<SLUG>-review.md`; `<SLUG>-report.md` остаётся нетронутым.
- `validator.md` и `formatter.md` из `/do/agents/` подключать через `${CLAUDE_PLUGIN_ROOT}`, дублирование запрещено.
- Нотификации через `${CLAUDE_PLUGIN_ROOT}/lib/notify.sh` — ACTION_REQUIRED перед AskUserQuestion, STAGE_COMPLETE в конце.
- Язык контента скилла — русский. Язык коммитов — английский.

## Verification

- Запуск `claude --plugin-dir .` → `/sp:review <SLUG>` → агент находит проблемы, показывает пользователю, исправляет, пишет отчёт
- `head -1 skills/review/SKILL.md` → `---` (YAML frontmatter)
- `head -1 skills/review/agents/*.md` → `---` (YAML frontmatter у каждого агента)
- `pnpm run format:check` → без ошибок
- `/sp:do` → `/sp:review` (post-flow) — читает report, исключает дублирующие findings
- `/sp:fix` → `/sp:review` — читает fix-log, исключает уже исправленное
- `/sp:review` standalone (без report/fixes) — полный code review с нуля
- Отчёт содержит секции: Summary, Issues Found, Fixed Issues, Skipped Issues, Recommendations
- При отсутствии проблем — отчёт без пустых таблиц, с пометкой "No issues found"

## Материалы

- [Тикет #44](https://github.com/projectory-com/sp/issues/44)
- [Code Review плагин Anthropic](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/code-review/README.md)
- [PR Review Toolkit Anthropic](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/pr-review-toolkit/README.md)
- `skills/review/SKILL.md` — текущий оркестратор
- `skills/review/agents/review-analyzer.md` — текущий агент
- `skills/do/SKILL.md` — паттерн pipeline
- `skills/do/reference/status-protocol.md` — протокол статусов
- `skills/do/agents/quality-reviewer.md` — паттерн классификации проблем
- `skills/fix/SKILL.md` — паттерн AskUserQuestion и scope guard
- `skills/gca/reference/commit-convention.md` — формат коммитов
