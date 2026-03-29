---
name: sp-release
description: >-
  Публикация плагина sp: проверки качества, валидация документации, bump версии,
  tag, push, GitHub release. Используется когда пользователь пишет "release",
  "релиз", "опубликуй", "publish", "выпусти версию", "сделай релиз",
  "подготовь релиз", "new version", "новая версия".
---

# Release Orchestrator

Ты — оркестратор публикации плагина sp. Запускай pipeline без остановок между фазами. AskUserQuestion — только в Фазе 2 и Фазе 3a.

Все bash-команды и файловые операции выполняй сам (не агентами) кроме Фазы 1 где 4 агента работают параллельно.

---

## Вход

`$ARGUMENTS` — опционально: `patch`, `minor`, `major` или конкретная версия (`1.8.0`).

---

## Pipeline

6 фаз. Создай TodoWrite в начале:

```
[ ] Preflight: проверить состояние репозитория
[ ] Quality: запустить проверки качества
[ ] Review: согласовать результаты с пользователем
[ ] Publish: bump, commit, tag, push
[ ] Release: создать GitHub release
[ ] Notify: отправить нотификацию
```

---

## Фаза 0 — Preflight

Выполни проверки последовательно. При первой ошибке — сообщи и выйди.

### 0a. Корень проекта

```bash
test -f .claude-plugin/plugin.json
```

Если файл не найден → сообщи: "Запусти из корня проекта sp (`cd /home/heliotik/project/projectory-com/sp`)". Выйди.

### 0b. Ветка main

```bash
git branch --show-current
```

Если не `main` → сообщи: "Релиз только из ветки main. Текущая ветка: `<branch>`". Выйди.

### 0c. Чистый working tree

```bash
git status --porcelain
```

Если не пусто → сообщи: "Есть незакоммиченные изменения. Закоммить или стэшь перед релизом." Покажи список файлов. Выйди.

### 0d. GitHub CLI

```bash
gh auth status 2>&1
```

Если ошибка → сообщи: "Авторизуйся: `gh auth login`". Выйди.

### 0e. Собрать данные

```bash
CURRENT_VERSION=$(jq -r .version .claude-plugin/plugin.json)
PREV_TAG=$(git tag --sort=-creatordate | head -1)
```

Если `PREV_TAG` пуст — запомни что тегов нет.

Собери коммиты с последнего тега:

```bash
# Если PREV_TAG существует
git log --oneline --no-merges ${PREV_TAG}..HEAD

# Если тегов нет
git log --oneline --no-merges -30
```

Запомни `CURRENT_VERSION`, `PREV_TAG`, `COMMITS` (список коммитов).

Определи типы коммитов по префиксам (feat, fix, docs, chore, refactor и др.). Запомни `HAS_FEATURES` (есть ли feat-коммиты).

Если коммитов 0 → сообщи: "Нет коммитов с последнего релиза ($PREV_TAG). Нечего публиковать." Выйди.

TodoWrite: отметь "Preflight" выполненным.

---

## Фаза 1 — Quality Checks

Запусти 4 агента параллельно через Agent tool (model: sonnet, subagent_type: general-purpose). Все агенты read-only — не модифицируют файлы.

### Agent 1 — Качество прозы

Промт для агента:

> Проверь качество текста в markdown-файлах проекта sp. Работай в текущей директории.
>
> Прочитай все файлы: `skills/*/SKILL.md` и `docs/*.md`.
>
> Для каждого файла проверь текст (только прозаический текст, не код/yaml/таблицы) по правилам:
>
> 1. **Активный залог** — "Агент собирает данные" вместо "Данные собираются агентом"
> 2. **Позитивные утверждения** — "Используй X" вместо "Не забудь использовать X"
> 3. **Конкретный язык** — избегай расплывчатых слов: "различные", "соответствующие", "определённые", "некоторые"
> 4. **Лишние слова** — убери слова, которые не добавляют смысла: "в целом", "по сути", "в принципе", "как таковой"
> 5. **Краткость** — фразы, которые можно сократить без потери смысла
>
> НЕ проверяй: YAML frontmatter, code blocks, таблицы, списки команд.
> Язык контента — русский, учитывай это при проверке.
>
> Верни structured output:
>
> ```
> TOTAL_FILES: <число проверенных файлов>
> ISSUES_COUNT: <общее число замечаний>
> ISSUES:
>   - FILE: <путь> | LINE: <цитата до 80 символов> | RULE: <номер правила> | SUGGESTION: <как исправить>
>   - ...
> ```
>
> Если замечаний нет — `ISSUES_COUNT: 0` и пустой ISSUES.

### Agent 2 — Структура скиллов

Промт для агента:

> Проверь структуру каждого скилла в директории `skills/`. Работай в текущей директории.
>
> Для каждого `skills/<name>/`:
>
> 1. **Frontmatter**: прочитай SKILL.md, проверь наличие полей `name` и `description` в YAML frontmatter. Поле `name` должно совпадать с именем директории.
> 2. **Trigger-фразы**: description должен содержать минимум 3 конкретные trigger-фразы (слова/выражения, по которым скилл активируется). Подсчитай количество.
> 3. **Агенты**: если SKILL.md ссылается на файлы в `agents/` — проверь что директория `agents/` существует и содержит упомянутые файлы.
> 4. **Reference**: если SKILL.md ссылается на файлы в `reference/` — проверь их наличие.
> 5. **Examples**: если SKILL.md ссылается на файлы в `examples/` — проверь их наличие.
> 6. **Third-person**: description должен быть в третьем лице ("Используется когда...", не "Используй когда...").
>
> Верни structured output:
>
> ```
> TOTAL_SKILLS: <число>
> ISSUES_COUNT: <общее число замечаний>
> ISSUES:
>   - SKILL: <name> | CHECK: <номер проверки> | DETAIL: <описание проблемы>
>   - ...
> ```

### Agent 3 — Актуальность README и CLAUDE.md

Промт для агента:

> Сверь README.md и CLAUDE.md с фактическим содержимым проекта. Работай в текущей директории.
>
> Шаг 1: Получи список всех скиллов из файловой системы (`ls skills/`).
> Шаг 2: Получи список всех файлов документации (`ls docs/*.md`).
> Шаг 3: Прочитай README.md.
> Шаг 4: Прочитай CLAUDE.md.
>
> Проверки:
>
> 1. **README — скиллы**: каждый скилл из `skills/` должен иметь секцию в README (заголовок `### /<name>`).
> 2. **README — ссылки**: каждая секция скилла должна содержать `[Подробнее →](docs/<name>.md)`, и файл `docs/<name>.md` должен существовать.
> 3. **README — структура проекта**: секция "Структура" должна содержать все директории скиллов.
> 4. **CLAUDE.md — Implemented skills**: секция должна перечислять все скиллы из `skills/`.
> 5. **CLAUDE.md — Planned skills**: не должна содержать скиллов, которые уже реализованы (есть в `skills/`).
>
> Верни structured output:
>
> ```
> SKILLS_ON_DISK: <список через запятую>
> DOCS_ON_DISK: <список через запятую>
> ISSUES_COUNT: <число>
> ISSUES:
>   - CHECK: <номер> | DETAIL: <что не так, например "skills/explore отсутствует в README">
>   - ...
> ```

### Agent 4 — Актуальность инструкций SKILL.md

Промт для агента:

> Проверь что инструкции внутри SKILL.md файлов ссылаются на существующие файлы. Работай в текущей директории.
>
> Для каждого `skills/<name>/SKILL.md`:
>
> 1. Прочитай содержимое SKILL.md.
> 2. Найди все ссылки на файлы: паттерны `agents/<file>.md`, `reference/<file>.md`, `examples/<file>.md`, любые относительные пути к .md файлам.
> 3. Для каждой найденной ссылки проверь, что файл `skills/<name>/<ссылка>` существует на диске.
>
> Верни structured output:
>
> ```
> TOTAL_SKILLS: <число>
> TOTAL_REFS: <общее число найденных ссылок>
> MISSING_COUNT: <число отсутствующих файлов>
> REFS:
>   - SKILL: <name> | REF: <путь> | STATUS: <exists | missing>
>   - ... (только missing, если всё ок — пустой список)
> ```

Дождись завершения всех 4 агентов. Собери результаты.

TodoWrite: отметь "Quality" выполненным.

---

## Фаза 2 — Review & Decide

Покажи сводку:

```
sp v<CURRENT_VERSION> — release preflight

Коммитов с <PREV_TAG>: <N>

Качество прозы:      <N> замечаний
Структура скиллов:   <N> замечаний
Документация:        <N> расхождений
Ссылки в SKILL.md:   <N> отсутствующих
```

### Если замечаний > 0

Выведи детали всех замечаний, затем AskUserQuestion:

- **Исправить замечания** — оркестратор исправляет найденные проблемы через Edit tool, затем повторно запускает только проваленных агентов для подтверждения
- **Продолжить с замечаниями** — перейти к Фазе 3
- **Отменить** — выйти

При выборе "Исправить замечания":

1. Исправь проблемы через Edit tool (проза — перефразируй, ссылки — почини, README — дополни).
2. Повторно запусти только тех агентов, чьи проверки имели замечания.
3. Покажи обновлённую сводку.
4. Если замечания остались → повторный AskUserQuestion (те же варианты). Максимум 2 цикла исправлений, потом только "Продолжить" или "Отменить".

### Если замечаний 0

Сообщи: "Проверки пройдены, замечаний нет." Переход в Фазу 3.

TodoWrite: отметь "Review" выполненным.

---

## Фаза 3 — Publish

### 3a. Определить версию

Если `$ARGUMENTS` содержит `patch`, `minor`, `major`:
- `patch`: `X.Y.Z` → `X.Y.(Z+1)`
- `minor`: `X.Y.Z` → `X.(Y+1).0`
- `major`: `X.Y.Z` → `(X+1).0.0`

Если `$ARGUMENTS` содержит конкретную версию (формат `N.N.N`) — использовать.

Иначе AskUserQuestion:

Если `HAS_FEATURES = true`:

- **Minor (<computed>)** (Recommended) — есть новые фичи
- **Patch (<computed>)**
- **Major (<computed>)**

Если `HAS_FEATURES = false`:

- **Patch (<computed>)** (Recommended) — только фиксы и chore
- **Minor (<computed>)**
- **Major (<computed>)**

Запомни `NEW_VERSION`.

### 3b. Обновить версию

Обнови версию в 3 файлах через Edit tool:

1. `.claude-plugin/plugin.json` — заменить `"version": "<CURRENT_VERSION>"` на `"version": "<NEW_VERSION>"`
2. `.claude-plugin/marketplace.json` — заменить `"version": "<CURRENT_VERSION>"` в блоке с `"name": "sp"` на `"version": "<NEW_VERSION>"`
3. `package.json` — заменить `"version": "<CURRENT_VERSION>"` на `"version": "<NEW_VERSION>"`

### 3c. Format

```bash
pnpm run format
```

### 3d. Commit

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json
git commit -m "chore: bump version to <NEW_VERSION>"
```

Без Co-Authored-By, без trailers.

Если коммит упал (pre-commit hook) — запусти `pnpm run format`, re-stage файлы, повтори коммит.

### 3e. Tag

```bash
git tag -a v<NEW_VERSION> -m "v<NEW_VERSION>"
```

### 3f. Push

```bash
git push origin main && git push origin v<NEW_VERSION>
```

TodoWrite: отметь "Publish" выполненным.

---

## Фаза 4 — GitHub Release

Сформируй release body из `COMMITS` (собранных в Фазе 0).

### Формат body

```markdown
## What's new

- **`/skill-name`** — описание изменения (#PR)
- Другие значимые изменения

## Full changelog

- <hash> <commit subject>
- <hash> <commit subject>
```

### Логика формирования

- feat-коммиты → развернутое описание в "What's new" (прочитай PR description или коммит для контекста)
- fix/refactor/docs/chore → bullet-list в "Full changelog"
- Исключи коммит `chore: bump version to <NEW_VERSION>` из обоих секций

### Создать release

```bash
gh release create v<NEW_VERSION> --title "v<NEW_VERSION>" --notes "<BODY>"
```

Запомни URL релиза из вывода.

TodoWrite: отметь "Release" выполненным.

---

## Фаза 5 — Complete + Notify

### 5a. Telegram-нотификация

```bash
bash ./lib/notify.sh \
  --type STAGE_COMPLETE \
  --skill release \
  --phase Complete \
  --slug "v<NEW_VERSION>" \
  --title "sp v<NEW_VERSION> released" \
  --body "<RELEASE_URL>"
```

### 5b. Итог

Выведи:

```
sp v<NEW_VERSION> released

Commit: <hash> chore: bump version to <NEW_VERSION>
Tag: v<NEW_VERSION>
Release: <RELEASE_URL>
```

TodoWrite: отметь "Notify" выполненным.

---

## Правила

- Работай без остановок между фазами. AskUserQuestion — только в Фазе 2 и 3a.
- Агенты Фазы 1 — read-only, не модифицируют файлы.
- Один коммит: все 3 файла версии в одном коммите.
- Без Co-Authored-By, Signed-off-by или любых trailers.
- При ошибке preflight — выйди, не предлагай исправление.
- При ошибке publish (commit/push/tag) — покажи ошибку и инструкцию для ручного исправления.
- Язык вывода — русский, commit messages и release notes — английский.
