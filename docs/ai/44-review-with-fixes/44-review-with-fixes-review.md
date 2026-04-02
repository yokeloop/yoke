# Code Review: 44-review-with-fixes

### Контекст и цель

Скилл `/review` переделан из простого анализатора изменений в полноценный code review pipeline с 6 фазами: Parse, Analyze, Select, Fix, Finalize, Complete. Добавлен поиск проблем с числовым скорингом 0-100 (Critical/Important/Minor), интерактивный выбор scope фиксов, автоматическое исправление через opus-агента и расширенный отчёт с таблицами исправленных/пропущенных проблем. Архитектура повторяет pipeline-паттерн из `/do` с context isolation через sub-agents.

### Коммиты

| Hash    | Описание                                                              |
| ------- | --------------------------------------------------------------------- |
| c40ba9d | docs(44-review-with-fixes): add task definition                       |
| 9a86ccd | docs(44-review-with-fixes): add implementation plan                   |
| e165930 | docs(44-review-with-fixes): add parallel fix agents to plan           |
| 4b91c01 | feat(44-review-with-fixes): add review report format template         |
| a7c1d41 | feat(44-review-with-fixes): add code-reviewer agent with issue scoring |
| 079f2d6 | feat(44-review-with-fixes): add issue-fixer orchestrator and single-fix-agent |
| 9affa7f | feat(44-review-with-fixes): add review-report-writer agent            |
| c740560 | feat(44-review-with-fixes): rewrite review skill with 6-phase pipeline |
| ee6dde3 | style(44-review-with-fixes): format review-format.md                  |
| f0ae7e0 | refactor(44-review-with-fixes): polish review skill prose             |
| 35b92ba | docs(44-review-with-fixes): add execution report                      |

### Изменённые файлы

| Файл                                              | +/-        | Описание                                                    |
| ------------------------------------------------- | ---------- | ----------------------------------------------------------- |
| docs/ai/44-review-with-fixes/44-review-with-fixes-task.md | +118       | Определение задачи: требования, контекст, constraints       |
| docs/ai/44-review-with-fixes/44-review-with-fixes-plan.md | +237       | План реализации: 7 design decisions, 6 tasks, execution order |
| docs/ai/44-review-with-fixes/44-review-with-fixes-report.md | +56      | Отчёт о выполнении                                          |
| skills/review/SKILL.md                            | +157/-31   | Оркестратор переписан: 4 фазы → 6 фаз pipeline              |
| skills/review/agents/code-reviewer.md             | +113       | Новый агент: анализ diff + поиск проблем со скорингом        |
| skills/review/agents/issue-fixer.md               | +67        | Новый агент-оркестратор: группировка issues, параллельные фиксы |
| skills/review/agents/single-fix-agent.md          | +49        | Новый атомарный исполнитель фиксов (opus)                    |
| skills/review/agents/review-report-writer.md      | +85        | Новый агент: расширенный отчёт с таблицами                   |
| skills/review/agents/review-analyzer.md           | -119       | Удалён: заменён на code-reviewer.md                          |
| skills/review/reference/review-format.md          | +101       | Шаблон отчёта с секциями Issues Found/Fixed/Skipped          |

### Ключевые участки для ревью

1. **`skills/review/SKILL.md:48-67`** — Фаза 1 Parse: логика определения SLUG и post-flow awareness (чтение report.md/fixes.md для исключения дублей)
2. **`skills/review/SKILL.md:71-79`** — Фаза 2 Analyze: dispatch code-reviewer и условный skip фаз 3-4 при отсутствии проблем
3. **`skills/review/SKILL.md:83-102`** — Фаза 3 Select: AskUserQuestion с 4 вариантами scope, фильтрация issues
4. **`skills/review/SKILL.md:106-125`** — Фаза 4 Fix: цепочка issue-fixer → validator → formatter, reuse агентов из /do
5. **`skills/review/SKILL.md:129-156`** — Фаза 5 Finalize: report-writer + PR-комментарии через gh api + commit artifact
6. **`skills/review/agents/code-reviewer.md:52-71`** — Шаг 3: поиск проблем по 7 категориям с числовым скорингом
7. **`skills/review/agents/issue-fixer.md:18-34`** — Группировка issues по файлам и параллельный dispatch
8. **`skills/review/agents/single-fix-agent.md:1-9`** — YAML frontmatter: model: opus для фиксов
9. **`skills/review/agents/review-report-writer.md:34-52`** — Заполнение шаблона данными из pipeline
10. **`skills/review/reference/review-format.md:28-101`** — Шаблон отчёта: таблицы Issues Found/Fixed/Skipped

### Сложные решения

1. **Двухуровневая система исправлений** (`skills/review/agents/issue-fixer.md:18-34`)
   Issue-fixer (sonnet) выступает оркестратором, группирует issues по файлам и dispatch'ит параллельные single-fix-agent'ы (opus). Независимые группы файлов параллелятся, пересекающиеся — последовательно. Trade-off: дополнительный уровень косвенности ради параллелизма и предотвращения конфликтов записи.

   ```
   Issues с одинаковым file — одна группа. Issues в разных файлах — разные группы.
   Группы без общих файлов — параллельно через Agent tool
   Группы с общими файлами — последовательно
   ```

2. **Post-flow awareness через чтение артефактов** (`skills/review/SKILL.md:61-65`)
   Оркестратор проверяет наличие `<SLUG>-report.md` и `<SLUG>-fixes.md` и передаёт содержимое code-reviewer как KNOWN_ISSUES. Trade-off: сопоставление проблем по тексту (не по ID) может давать ложные совпадения или пропуски.

   ```
   - docs/ai/<SLUG>/<SLUG>-report.md — прочитай секции Concerns и quality review results → собери KNOWN_ISSUES
   - docs/ai/<SLUG>/<SLUG>-fixes.md — прочитай список исправлений → добавь к KNOWN_ISSUES
   - Артефактов нет — KNOWN_ISSUES = `—`
   ```

3. **PR-комментарии для пропущенных issues** (`skills/review/SKILL.md:133-143`)
   Skipped issues публикуются как PR-комментарии через `gh api`. Используется общий endpoint comments, а не review comments с привязкой к строкам. Trade-off: комментарии без привязки к diff-строкам менее информативны, но проще в реализации и не требуют вычисления position.

4. **Удаление review-analyzer.md и замена на code-reviewer.md** (`skills/review/agents/code-reviewer.md`)
   Вместо расширения старого агента создан новый с другим именем и расширенной логикой (7 категорий + скоринг). Trade-off: breaking change для тех, кто напрямую ссылался на review-analyzer.md (маловероятно при текущей архитектуре).

### Вопросы к ревьюеру

1. Достаточно ли текстового сопоставления для KNOWN_ISSUES (post-flow awareness), или нужен более формальный механизм дедупликации?
2. PR-комментарии используют endpoint `pulls/{number}/comments` (issue comments). Стоит ли использовать `pulls/{number}/reviews` с inline-комментариями для лучшего UX?
3. Issue-fixer использует model: sonnet как оркестратор, single-fix-agent — model: opus. Оправдано ли использование opus для каждого фикса, учитывая стоимость при большом количестве issues?
4. Code-reviewer не имеет Write/Edit tools — только Read, Bash, Glob, Grep, LS. Корректно ли это для агента, который только анализирует?
5. Фаза 4 вызывает validator и formatter из /do через `${CLAUDE_PLUGIN_ROOT}`. Есть ли тесты, подтверждающие что эти агенты корректно работают вне контекста /do?
6. В Фазе 5 commit artifact делается напрямую оркестратором (bash git add/commit), а не через sub-agent. Это нарушает правило "тонкий оркестратор" из секции Правила?

### Риски и влияние

- **Стоимость opus при многих issues**: каждый single-fix-agent запускается как opus. При 10+ issues в разных файлах — 10+ параллельных opus-вызовов.
- **Конфликты параллельных фиксов**: группировка по файлам снижает риск, но если один fix меняет imports, а другой — зависимый код в другом файле, возможен broken build.
- **Обратная совместимость**: /do и /fix вызывают `/sp:review` через Skill tool. Pipeline стал длиннее (6 фаз vs 4), время выполнения увеличится. Пауза на AskUserQuestion в Фазе 3 может блокировать автоматический flow /do.
- **gh api зависимость**: PR-комментарии требуют авторизованный gh CLI. При отсутствии токена или прав — silent failure (2>/dev/null в gh pr view).
- **Размер контекста code-reviewer**: agent получает полный `git diff origin/main...HEAD`. При больших PR diff может превысить лимит контекста sonnet.

### Тесты и ручные проверки

**Авто-тесты:**

- `pnpm run format:check` — форматирование всех markdown-файлов
- `head -1 skills/review/SKILL.md skills/review/agents/*.md` — YAML frontmatter начинается с `---`
- JSON-валидация манифестов (plugin.json, marketplace.json) не затронута

**Ручные сценарии:**

1. `/sp:review 44-review-with-fixes` standalone → code-reviewer находит проблемы, показывает список, предлагает scope → ожидается полный pipeline до отчёта
2. `/sp:review` без аргументов → определяет SLUG из текущей ветки → ожидается автоопределение
3. `/sp:review` после `/sp:do` (есть report.md) → читает KNOWN_ISSUES, исключает дубли → ожидается меньше findings
4. `/sp:review` после `/sp:fix` (есть fixes.md) → исключает уже исправленное → ожидается корректная фильтрация
5. Выбор "Skip fixes" в Фазе 3 → все issues в Skipped → ожидается отчёт без фиксов
6. Выбор "Fix all" при наличии PR → skipped issues публикуются как PR-комментарии
7. Diff без проблем (ISSUES_COUNT = 0) → Фазы 3-4 пропускаются → отчёт с "Проблем не найдено"
8. Вызов из `/sp:do` Фаза 7 → review работает без изменений интерфейса

### Out of scope

- Изменения в `/do` и `/fix` — интерфейс вызова сохранён, эти скиллы не менялись
- Inline PR-комментарии с привязкой к строкам diff — используется упрощённый endpoint
- Кеширование результатов code-reviewer между запусками
- Автоматический rerun после фиксов (повторный code review исправленного кода)
- Unit-тесты для pipeline — проект не имеет тестовой инфраструктуры
- Скилл `/polish` упомянут в planned — не реализован в этом PR
