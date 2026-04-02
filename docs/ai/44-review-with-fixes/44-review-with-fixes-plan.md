# Переделать /review: code review + автоматическое исправление — план реализации

**Task:** docs/ai/44-review-with-fixes/44-review-with-fixes-task.md
**Complexity:** complex
**Mode:** sub-agents
**Parallel:** true

## Design decisions

### DD-1: Pipeline из 6 фаз по образцу /do

**Решение:** Parse → Analyze → Select → Fix → Finalize → Complete. Оркестратор координирует 4 агента (code-reviewer, issue-fixer + single-fix-agent, report-writer) и reuse-агенты из /do.
**Обоснование:** /do (`skills/do/SKILL.md`) доказал pipeline-паттерн с sub-agents. /review повторяет структуру: каждая фаза — dispatch агента, обработка статуса, переход.
**Альтернатива:** Monolith-агент (всё в одном) — теряет context isolation, превышает лимит контекста при большом diff.

### DD-2: Переименовать review-analyzer.md → code-reviewer.md

**Решение:** Удалить `agents/review-analyzer.md`, создать `agents/code-reviewer.md` с новой логикой: поиск проблем, числовой скоринг 0-100, классификация Critical/Important/Minor.
**Обоснование:** Текущий review-analyzer описывает изменения, но не ищет проблемы. Новый code-reviewer совмещает описание и поиск багов. Имя `code-reviewer` точнее отражает роль.
**Альтернатива:** Расширить review-analyzer — имя становится misleading, агент разрастается.

### DD-3: Формат вывода code-reviewer — структурированные блоки

**Решение:** Code-reviewer возвращает две секции: SUMMARY (7 измерений, как сейчас) и ISSUES (список проблем со score, severity, file:line, description, suggested_fix). Оркестратор парсит ISSUES для передачи в issue-fixer.
**Обоснование:** Структурированный формат позволяет оркестратору фильтровать issues по severity и передавать в issue-fixer только выбранные. Паттерн из quality-reviewer.md (`skills/do/agents/quality-reviewer.md:63-75`): VERDICT + ISSUES + ASSESSMENT.
**Альтернатива:** JSON-формат — сложнее для LLM-генерации, чаще ломается парсинг.

### DD-4: Issue-fixer получает отфильтрованный список

**Решение:** Оркестратор показывает пользователю все issues через AskUserQuestion, пользователь выбирает scope (All Critical+Important / Only Critical / Custom / Skip). Оркестратор фильтрует и передаёт issue-fixer только выбранные.
**Обоснование:** Паттерн AskUserQuestion из /fix (`skills/fix/SKILL.md:130-134`): варианты с рекомендацией. Фильтрация на стороне оркестратора — issue-fixer получает чистый список, группирует по файлам и dispatch'ит параллельные fix-агенты (DD-7).
**Альтернатива:** Issue-fixer сам фильтрует — нарушает принцип context isolation, пользователь теряет контроль.

### DD-5: Post-flow и fix-log awareness через чтение артефактов

**Решение:** В фазе Parse оркестратор проверяет наличие `<SLUG>-report.md` и `<SLUG>-fixes.md`. Если существуют — читает и передаёт code-reviewer как `KNOWN_ISSUES` для исключения дублей.
**Обоснование:** report.md содержит quality review results из /do, fixes.md — журнал исправлений из /fix. Code-reviewer исключает уже известные проблемы на этапе анализа.
**Альтернатива:** Фильтрация после анализа — двойная работа, сложнее сопоставление.

### DD-7: Issue-fixer как оркестратор параллельных fix-агентов

**Решение:** Issue-fixer группирует issues по файлам. Issues, затрагивающие разные файлы, dispatch'ит параллельным sub-agent'ам (каждый — отдельный Agent tool call с model: opus). Issues, затрагивающие один файл, объединяет в одну группу и выполняет sequential. После завершения всех — один общий коммит.
**Обоснование:** При 5+ issues в разных файлах параллельные fix-агенты сокращают время в 2-3 раза. Группировка по файлам исключает конфликты записи. Паттерн parallel dispatch из /do (`skills/do/reference/status-protocol.md:109-131`): параллельные группы без общих файлов.
**Альтернатива:** Один проход (sequential) — проще, но медленнее при большом количестве issues. Оправдан только при 1-3 issues или если все в одном файле.

### DD-6: Обязательное использование скиллов при разработке и валидации

**Решение:** Каждый task, создающий или изменяющий SKILL.md или агентов, обязан использовать скиллы `elements-of-style:writing-clearly-and-concisely` (проза), `plugin-dev:skill-development` (структура скилла), `plugin-dev:agent-development` (структура агента). Финальный task валидации проверяет качество через эти же скиллы.
**Обоснование:** Пользователь явно запросил. Скиллы обеспечивают единообразие прозы (активный залог, конкретный язык) и соответствие plugin-системе (YAML frontmatter, description, tool access).
**Альтернатива:** Ручная проверка — субъективна, пропускает отклонения.

## Tasks

### Task 1: Создать reference/review-format.md

- **Files:** `skills/review/reference/review-format.md` (create)
- **Depends on:** none
- **Scope:** S
- **What:** Создать шаблон расширенного review-отчёта с секциями: Summary, Commits, Changed Files, Issues Found (таблица: severity, score, file:line, description), Fixed Issues (таблица: commit, description), Skipped Issues (таблица: reason), Recommendations.
- **How:**
  1. Использовать скилл `elements-of-style:writing-clearly-and-concisely` — проверить прозу шаблона
  2. Взять за основу текущий формат из `agents/review-analyzer.md:56-103` (7 секций)
  3. Добавить таблицы Issues Found / Fixed / Skipped по паттерну report-format.md из /do (`skills/do/reference/report-format.md`)
  4. Добавить секцию Recommendations for PR Review
  5. Предусмотреть кейс "No issues found" — заменить пустые таблицы текстом
- **Context:** `skills/review/agents/review-analyzer.md:56-103`, `skills/do/reference/report-format.md`
- **Verify:** `head -1 skills/review/reference/review-format.md` → `#`; файл содержит секции Summary, Issues Found, Fixed Issues, Skipped Issues, Recommendations

### Task 2: Создать code-reviewer.md (замена review-analyzer.md)

- **Files:** `skills/review/agents/code-reviewer.md` (create), `skills/review/agents/review-analyzer.md` (delete)
- **Depends on:** none
- **Scope:** M
- **What:** Создать агента code-reviewer (sonnet), который собирает git diff, анализирует по 7+ категориям (bugs, quality, style, documentation, tests, performance, security), присваивает каждой проблеме числовой скор 0-100 и severity (Critical 80-100, Important 50-79, Minor 0-49). Возвращает SUMMARY + ISSUES.
- **How:**
  1. Использовать скилл `plugin-dev:agent-development` — структура агента, YAML frontmatter, tool access
  2. Использовать скилл `elements-of-style:writing-clearly-and-concisely` — проверить прозу агента
  3. YAML frontmatter: `name: code-reviewer`, `model: sonnet`, `tools: Read, Bash, Glob, Grep, LS`
  4. Шаг 1 — сбор данных: `git log origin/main..HEAD`, `git diff origin/main...HEAD --stat`, `git diff origin/main...HEAD` (как в review-analyzer.md:18-26)
  5. Шаг 2 — анализ по 7 измерениям (как в review-analyzer.md:38-49), плюс поиск конкретных проблем с присвоением score
  6. Шаг 3 — принять `KNOWN_ISSUES` (из report.md/fixes.md), исключить совпадающие
  7. Формат вывода: блок SUMMARY (7 измерений) + блок ISSUES (нумерованный список с полями: severity, score, category, file:line, description, suggested_fix)
  8. Удалить `review-analyzer.md`
- **Context:** `skills/review/agents/review-analyzer.md:1-119` (текущий агент — основа), `skills/do/agents/quality-reviewer.md:57-75` (паттерн классификации и формата)
- **Verify:** `head -1 skills/review/agents/code-reviewer.md` → `---`; файл содержит YAML frontmatter с `model: sonnet`; `ls skills/review/agents/review-analyzer.md` → файл удалён

### Task 3: Создать issue-fixer.md и single-fix-agent.md

- **Files:** `skills/review/agents/issue-fixer.md` (create), `skills/review/agents/single-fix-agent.md` (create)
- **Depends on:** none
- **Scope:** M
- **What:** Создать двухуровневую систему исправления: issue-fixer (оркестратор, sonnet) группирует issues по файлам и dispatch'ит параллельные single-fix-agent'ы (opus) для независимых групп. Issues в одном файле идут в одну группу sequential.
- **How:**
  1. Использовать скилл `plugin-dev:agent-development` — структура агентов, YAML frontmatter
  2. Использовать скилл `elements-of-style:writing-clearly-and-concisely` — проверить прозу
  3. **single-fix-agent.md** — атомарный исполнитель:
     - YAML frontmatter: `name: single-fix-agent`, `model: opus`, `tools: Read, Edit, Bash, Glob, Grep, LS`
     - Вход: список ISSUES для одной группы файлов, CONSTRAINTS
     - Процесс: прочитать файл, применить fix, проверить что не сломал соседний код
     - Формат вывода: FIXED (список) + SKIPPED (список с причиной) + FILES_CHANGED
  4. **issue-fixer.md** — оркестратор:
     - YAML frontmatter: `name: issue-fixer`, `model: sonnet`, `tools: Read, Bash, Glob, Grep`
     - Вход: список ISSUES (severity, score, file:line, description, suggested_fix), SLUG, TICKET_ID, CONSTRAINTS
     - Шаг 1: группировка issues по файлам (issues с одинаковым file → одна группа)
     - Шаг 2: dispatch параллельных single-fix-agent'ов через Agent tool для групп без общих файлов
     - Шаг 3: дождаться завершения всех, собрать FIXED/SKIPPED/FILES_CHANGED
     - Шаг 4: один коммит: `TICKET fix(SLUG): fix N review issues`
     - Fallback: при 1-3 issues в одном файле — dispatch одного single-fix-agent без параллелизма
  5. Паттерн parallel dispatch из status-protocol.md (`skills/do/reference/status-protocol.md:109-131`)
- **Context:** `skills/do/agents/task-executor.md:1-30` (паттерн агента-исполнителя), `skills/do/reference/status-protocol.md:109-131` (parallel dispatch), `skills/do/agents/quality-reviewer.md:57-75` (формат issues)
- **Verify:** `head -1 skills/review/agents/issue-fixer.md skills/review/agents/single-fix-agent.md` → оба начинаются с `---`; issue-fixer содержит `model: sonnet`; single-fix-agent содержит `model: opus`

### Task 4: Создать review-report-writer.md

- **Files:** `skills/review/agents/review-report-writer.md` (create)
- **Depends on:** none
- **Scope:** M
- **What:** Создать агента report-writer (sonnet), который получает данные из code-reviewer и issue-fixer, читает review-format.md и записывает расширенный отчёт `<SLUG>-review.md`.
- **How:**
  1. Использовать скилл `plugin-dev:agent-development` — структура агента
  2. Использовать скилл `elements-of-style:writing-clearly-and-concisely` — проверить прозу
  3. YAML frontmatter: `name: review-report-writer`, `model: sonnet`, `tools: Read, Write, Bash, Glob, Grep`
  4. Вход: SLUG, SUMMARY (из code-reviewer), ALL_ISSUES, FIXED_ISSUES, SKIPPED_ISSUES, COMMIT_HASHES
  5. Процесс: прочитать `reference/review-format.md`, заполнить шаблон данными
  6. Кейс "No issues found": вместо пустых таблиц — текст "No issues found"
  7. Секция Recommendations: сгенерировать на основе skipped issues и общего анализа
  8. Формат вывода: `REVIEW_FILE: docs/ai/<SLUG>/<SLUG>-review.md`
- **Context:** `skills/review/reference/review-format.md` (Task 1), `skills/do/agents/report-writer.md` (паттерн report-агента)
- **Verify:** `head -1 skills/review/agents/review-report-writer.md` → `---`

### Task 5: Переписать SKILL.md — pipeline из 6 фаз

- **Files:** `skills/review/SKILL.md` (rewrite)
- **Depends on:** Task 1, Task 2, Task 3, Task 4
- **Scope:** L
- **What:** Переписать оркестратор /review с pipeline из 6 фаз: Parse → Analyze → Select → Fix → Finalize → Complete. Автономный режим с двумя паузами (scope selection, final action).
- **How:**
  1. Использовать скилл `plugin-dev:skill-development` — структура скилла, YAML frontmatter, description
  2. Использовать скилл `elements-of-style:writing-clearly-and-concisely` — вся проза активным залогом
  3. Сохранить текущий YAML frontmatter (name: review, description обновить)
  4. **Фаза 1 — Parse:**
     - Определить SLUG из $ARGUMENTS / ветки / docs/ai/\*/ (как сейчас, строки 29-39)
     - Извлечь TICKET_ID по commit-convention.md
     - Проверить наличие `<SLUG>-report.md` и `<SLUG>-fixes.md` → прочитать как KNOWN_ISSUES
  5. **Фаза 2 — Analyze:**
     - Dispatch code-reviewer.md (sonnet) с SLUG, task-file, KNOWN_ISSUES
     - Получить SUMMARY + ISSUES
     - Если ISSUES пусто → пропустить Фазы 3-4, перейти к Фазе 5
  6. **Фаза 3 — Select:**
     - Отправить нотификацию: `notify.sh --type ACTION_REQUIRED --skill review --phase Select`
     - Показать все issues через AskUserQuestion с вариантами:
       a) "Fix all Critical + Important (Recommended)" — исключить Minor
       b) "Fix only Critical" — только score >= 80
       c) "Fix all" — все issues
       d) "Skip fixes" — только отчёт, без исправлений
     - Отфильтровать issues по выбору → ISSUES_TO_FIX, ISSUES_TO_SKIP
  7. **Фаза 4 — Fix:**
     - Если ISSUES_TO_FIX не пусто:
       a) Dispatch issue-fixer.md (sonnet-оркестратор) с ISSUES_TO_FIX, SLUG, TICKET_ID
       b) Issue-fixer группирует issues по файлам, dispatch'ит параллельные single-fix-agent'ы (opus) для независимых групп (DD-7)
       c) Получить FIXED_ISSUES, SKIPPED_ISSUES, FILES_CHANGED
       d) Dispatch validator.md из /do через `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/validator.md`
       e) Dispatch formatter.md из /do через `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/formatter.md`
     - Если "Skip fixes" → все issues в SKIPPED_ISSUES
  8. **Фаза 5 — Finalize:**
     - Dispatch review-report-writer.md с данными из Фаз 2 и 4
     - PR-комментарии: если `gh pr view` находит PR — постить skipped issues через `gh api`
     - Commit report artifact: `TICKET docs(SLUG): add review report`
  9. **Фаза 6 — Complete:**
     - Нотификация: `notify.sh --type STAGE_COMPLETE --skill review`
     - AskUserQuestion: "Push (/sp:gp)" / "Create PR (/sp:pr)" / "Завершить"
  10. Обратная совместимость: $ARGUMENTS = SLUG, вызов из /do и /fix без изменений
- **Context:** `skills/review/SKILL.md:1-91` (текущий оркестратор), `skills/do/SKILL.md:1-50` (pipeline-паттерн), `skills/fix/SKILL.md:106-134` (scope guard + AskUserQuestion), `skills/fix/SKILL.md:176-206` (reuse агентов /do через ${CLAUDE_PLUGIN_ROOT})
- **Verify:** `head -1 skills/review/SKILL.md` → `---`; YAML frontmatter с name: review; файл содержит 6 фаз; `pnpm run format:check` без ошибок

### Task 6: Валидация и проверка качества

- **Files:** —
- **Depends on:** all
- **Scope:** M
- **What:** Запустить полную валидацию: format check, YAML frontmatter, проверку качества скиллов и агентов через скиллы.
- **How:**
  1. `pnpm run format:check` — без ошибок
  2. `head -1 skills/review/SKILL.md skills/review/agents/*.md` — каждый начинается с `---`
  3. Использовать скилл `plugin-dev:skill-development` — валидация SKILL.md (frontmatter, description, structure)
  4. Использовать скилл `plugin-dev:agent-development` — валидация каждого агента (frontmatter, tools, model)
  5. Использовать скилл `elements-of-style:writing-clearly-and-concisely` — проверить прозу во всех файлах skills/review/
  6. Проверить обратную совместимость: SKILL.md принимает SLUG через $ARGUMENTS
  7. Проверить что `/do` Фаза 7 (`skills/do/SKILL.md:283-288`) вызывает `/sp:review` без изменений
  8. Проверить что `/fix` Фаза 7 (`skills/fix/SKILL.md:249`) вызывает `/sp:review` без изменений
- **Context:** `skills/do/SKILL.md:280-290`, `skills/fix/SKILL.md:245-255`
- **Verify:** Все проверки пройдены, format check зелёный, frontmatter валидный

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** 6 tasks, Tasks 1-4 изменяют разные файлы без пересечений — параллелятся. Task 5 зависит от 1-4 (ссылается на все агенты). Task 6 зависит от всех. Одна кодовая база, cross-layer отсутствует.
- **Order:**
  ```
  Group 1 (parallel):
    Task 1: reference/review-format.md
    Task 2: code-reviewer.md
    Task 3: issue-fixer.md
    Task 4: review-report-writer.md
  ─── barrier ───
  Group 2 (sequential):
    Task 5: SKILL.md (pipeline orchestrator)
  ─── barrier ───
  Group 3 (sequential):
    Task 6: Validation + skill quality check
  ```

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

## Materials

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
