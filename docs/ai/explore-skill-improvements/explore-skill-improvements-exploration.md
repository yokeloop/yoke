# Exploration: подскажи по скилу explore можно ли через него сейчас создать issue или тикет ?

**Date:** 2026-04-20
**Questions:** 2

---

## Q1: подскажи по скилу explore можно ли через него сейчас создать issue или тикет ?

### Context

Первый вопрос сессии. Пользователь обдумывает границы функционала /yoke:explore и хочет понять, можно ли в
текущей реализации создавать через этот скилл GitHub issue или тикет в другой системе, или же explore строго
read-only. Это прелюдия к следующему вопросу об улучшениях — пользователь сначала сверяет текущее состояние.

### Answer

Нет, скилл `/yoke:explore` сейчас не умеет создавать issue или тикет. Это исключительно read-only режим:
исследование кодовой базы + Q&A, итог которого — локальный markdown-файл с логом, а не тикет в GitHub/Jira.

### Details

1. Агент explore-agent — read-only по дизайну
   - `skills/explore/agents/explore-agent.md:6` явно ограничивает инструменты:
     ```
     tools: Glob, Grep, LS, Read, Bash, WebSearch, WebFetch
     ```
   - Нет `Write`, нет `Edit`. В правилах (`skills/explore/agents/explore-agent.md:97`) прямо прописано:
     `Read-only. Write and Edit are unavailable.`
   - Bash нужен только для `git log --oneline`, `wc -l` и подобного чтения (`explore-agent.md:40`).

2. Оркестратор SKILL.md — никакого создания тикетов
   - `skills/explore/SKILL.md:32-38` описывает три фазы: Init → Loop (Q&A) → Finalize.
   - В Finalize (`SKILL.md:121-143`) единственное действие — диспатч `explore-log-writer`, который пишет
     локальный файл.
   - В описании скилла (`SKILL.md:2-9`) нет ни слова про issue/ticket/GitHub.

3. Log-writer пишет только в docs/ai
   - `skills/explore/agents/explore-log-writer.md:37` жёстко зашивает путь:
     `EXPLORATION_LOG="docs/ai/{{SLUG}}/{{SLUG}}-exploration.md"`
   - Инструменты писателя — `Read, Write, Edit, Bash` (`explore-log-writer.md:5`), но правило
     `explore-log-writer.md:85` говорит: `Do not commit — only create/update the file.` То есть даже коммита
     нет, не то что `gh issue create`.

4. Во всей кодовой базе yoke поиск `gh issue create` пустой
   - `grep -i "gh issue"` по `skills/` находит только одно упоминание в `skills/task/SKILL.md:37` —
     `GitHub Issues → gh issue view <url>`, и это чтение существующего тикета в скилле `/yoke:task`, а не
     создание.
   - Никакого `gh issue create` в yoke вообще нет.

5. Чем отличаются соседние скиллы
   - `/yoke:task` — читает тикет (issue/URL) и делает из него task-файл; issue не создаёт.
   - `/yoke:pr` — создаёт Pull Request через `gh pr create`, но PR, а не issue.
   - `/yoke:explore` — не трогает внешние системы вообще.

Что можно делать сейчас, если нужен тикет из /explore:

- Сохранить сессию (Phase 3 → `docs/ai/<slug>/<slug>-exploration.md`) и вручную скопировать Summary/Options в
  `gh issue create`.
- Использовать файл-лог как вход для `/yoke:task`, если цель — задача на реализацию, а не тикет-обсуждение.

### Key files

- `skills/explore/agents/explore-agent.md:6` — список инструментов агента: Glob, Grep, LS, Read, Bash,
  WebSearch, WebFetch; нет Write/Edit.
- `skills/explore/agents/explore-agent.md:97` — явное правило «Read-only. Write and Edit are unavailable.»
- `skills/explore/SKILL.md:121-143` — фаза Finalize: единственный side-effect — локальный md-файл через
  log-writer.
- `skills/explore/agents/explore-log-writer.md:37` — хардкод пути `docs/ai/<SLUG>/<SLUG>-exploration.md`.
- `skills/explore/agents/explore-log-writer.md:85` — правило «Do not commit — only create/update the file.»
- `skills/task/SKILL.md:37` — единственное упоминание `gh issue` во всём yoke — и то только `gh issue view`
  (чтение).

---

## Q2: Пользователь хочет улучшить explore двумя способами — (1) создание issue/тикета на основе накопленных Q&A сессии, (2) убрать лишний клик "Ask another question" в меню после каждого ответа — хочет сразу писать следующий вопрос без промежуточного шага. Дай brainstorm опций по обоим улучшениям. (brainstorm)

### Context

Продолжение после Q1, где выяснилось, что текущий explore не умеет создавать issue. Теперь пользователь
формулирует желаемое улучшение: (1) добавить создание issue из материала сессии, (2) убрать UX-трение из Loop,
где после каждого ответа AskUserQuestion заставляет выбрать "Ask another question" перед вводом. Цель
вопроса — получить набор опций и ориентиры по встраиванию (в какие файлы/фазы) до того, как превратить это в
план или задачу.

### Answer

Сейчас `/yoke:explore` не умеет создавать issues — агент `explore-agent` read-only
(`skills/explore/agents/explore-agent.md:6`), `explore-log-writer` только пишет markdown и не коммитит
(`skills/explore/agents/explore-log-writer.md:85`). Ближайший аналог записи через `gh` — `/yoke:pr`, который
вызывает `gh pr create` прямо в оркестраторе (`skills/pr/SKILL.md:100`). Для обоих вопросов есть 3-4 варианта
реализации; ключевая развилка — ставить ли промежуточную менюшку или менять модель "orchestrator спрашивает"
на "orchestrator просто ждёт новый ввод".

### Details

Текущее состояние explore:

- Фаза 2 — цикл (`SKILL.md:60-117`). Шаг 2e (`SKILL.md:105-111`) — `AskUserQuestion` с меню
  `{Ask another question / Save and finish / Continue without saving}`. Именно там лишний клик.
- Финализация (`SKILL.md:121-143`) идёт через `AskUserQuestion` для slug + дожатие `explore-log-writer`. После
  Finalize нет шага "создать issue" — артефакт только файл.
- В `docs/explore.md:23` указана Phase 4 Complete с
  `AskUserQuestion: another question / create a task via /yoke:task / finish`, но в `SKILL.md` её нет — это
  уже расхождение между доком и кодом скилла (указывает, что Phase 4 изначально планировалась).

Паттерны записи через gh в yoke:

- `/yoke:pr` оркестратор сам вызывает `gh pr create --title --body --base [--draft]`
  (`skills/pr/SKILL.md:99-101`), тело генерит `pr-body-generator`
  (`skills/pr/agents/pr-body-generator.md`), данные собирает `pr-data-collector` (у которого есть
  `gh auth status` и label listing, `skills/pr/agents/pr-data-collector.md:47-112`). Это готовая калька для
  `gh issue create`.
- `/yoke:review` дёргает `gh api --method POST repos/{owner}/{repo}/issues/{number}/comments` для публикации
  комментов (`skills/review/SKILL.md:140-142`) — показывает, что в yoke уже есть паттерн "оркестратор
  публикует в GH через gh api".
- `/yoke:task` читает issue (`gh issue view`, `skills/task/SKILL.md:37`), но не создаёт — то есть явный пробел
  в обратную сторону.

Паттерны "free-form next input":

- Нигде в yoke между фазами нет модели "просто ждать следующего сообщения пользователя без меню". Везде либо
  `AskUserQuestion` с опциями, либо работа end-to-end без остановок.
- Исключения: `skills/bootstrap/SKILL.md:290` — "wait for the user's signal" после Review-and-edit, но это без
  формального механизма.
- `skills/explore/SKILL.md:151` уже содержит правило "Wait for questions from the user", но сразу перед этим
  шаг 2e даёт меню — противоречие.
- В `skills/task/SKILL.md:152` и `skills/plan/SKILL.md:162` паттерн "Other для free-form input" встроен в
  AskUserQuestion — компромисс, но не полное решение.

### Options

- [ ] **A1. Новая Phase 4 "Create issue?" после Finalize (симметрия с /yoke:task → /yoke:plan handoff)** —
      После того как `explore-log-writer` записал файл, оркестратор спрашивает `AskUserQuestion`:
      `{Create GitHub issue / Handoff to /yoke:task / Finish}`. При выборе "Create issue" оркестратор (а)
      проверяет `gh auth status` и `gh repo view`, (б) дёргает нового агента `explore-issue-writer` (haiku),
      который по `QA_LOG` + `EXPLORATION_SUMMARY` синтезирует title+body (как `pr-body-generator` делает это
      для PR), (в) вызывает `gh issue create --title --body [--label exploration]`, (г) печатает URL. Плюсы:
      изоморфно паттерну `/pr`, минимум инвазивности, не трогает Loop. Минусы: ещё один клик в конце, issue
      всегда из всей сессии целиком (нельзя "за этот вопрос — заведи issue"). Встраивание: SKILL.md Phase 3 →
      добавить Phase 4 "Issue", новый агент `skills/explore/agents/explore-issue-writer.md` по аналогии с
      `skills/pr/agents/pr-body-generator.md`. Evidence: `skills/pr/SKILL.md:99-101` (gh pr create в
      оркестраторе), `skills/task/SKILL.md:263-273` (паттерн handoff-меню после основной работы).

- [ ] **A2. Per-question флаг "issue from this Q&A"** — В шаге 2e меню расширяется до
      `{Next question / Save and finish / Create issue from last answer / Continue without saving}`. Если
      пользователь жмёт "Create issue from last answer" — оркестратор берёт последний QA_LOG record +
      EXPLORATION_SUMMARY как контекст, передаёт в `explore-issue-writer`, создаёт issue, возвращается к 2a.
      Плюсы: точечные issue по конкретным находкам (brainstorm с опциями → issue с options как checkboxes).
      Минусы: разрастает меню до 4 опций, усложняет state (надо помнить, что из Q3 уже сделана issue, чтобы не
      дублировать). Встраивание: `skills/explore/SKILL.md:107-111` (шаг 2e) + новый агент. Evidence:
      `skills/review/SKILL.md:134-144` (паттерн "публиковать findings как GH комменты per-issue").

- [ ] **A3. Opt-in слэш-команда /yoke:explore-issue \<slug\> отдельно** — Оставить `/yoke:explore` как есть
      (только файл), но добавить отдельный скилл `/yoke:explore-issue <slug>`, который читает готовый
      `docs/ai/<slug>/<slug>-exploration.md`, синтезирует issue и создаёт его через `gh issue create`. Плюсы:
      нулевая нагрузка на explore loop, можно запустить через недели после сессии, чистая граница
      ответственности. Минусы: лишняя команда в линейке, пользователь должен помнить slug. Встраивание: новый
      `skills/explore-issue/SKILL.md`, переиспользует `reference/exploration-log-format.md` как схему входа.
      Evidence: `skills/task/SKILL.md:37` (симметричный паттерн "отдельный скилл per-direction I/O").

- [ ] **A4. Inline команды внутри Loop - "/issue" как user intent** — Вместо меню в 2e пользователь может в
      свободном поле набрать спец-команду — первая строка начинается с `/issue <заголовок>` → оркестратор
      распознаёт это как сигнал "создай issue из предыдущего Q&A" (а не новый вопрос). Остальной текст —
      тело/уточнение для issue. Плюсы: нулевой клик, работает в паре с опцией B2/B3 (свободный ввод). Минусы:
      скрытый API, нужно документировать, легко промахнуться с синтаксисом. Встраивание: расширить шаг 2a в
      `SKILL.md:64-71` — парсинг intent перед тем как отправлять агенту. Evidence: `skills/fix/SKILL.md:36`
      (парсинг $ARGUMENTS на наличие pull/...#discussion_r... URL как intent-switch — аналогичный подход).

- [ ] **B1. Дефолтная опция "Ask another question" + auto-continue** — Оставить AskUserQuestion в 2e, но
      опцию "Ask another question" пометить (Recommended) и встроить явную инструкцию оркестратору: "After
      showing the answer, if the user's next message is not an explicit save/finish word — treat it as a new
      question, skipping the menu". Меню показывается только при явных сигналах завершения. Плюсы: минимальная
      правка в SKILL.md, сохраняет механизм Save and finish через stop-word. Минусы: правила stop-word надо
      явно перечислить (stop, done, save, finish), интернационализировать (русский/английский), и это
      хрупко — может ложно триггернуться. Встраивание: переписать 2e (`SKILL.md:105-112`) в раздел правил 2f.
      Evidence: `skills/bootstrap/SKILL.md:290` ("wait for the user's signal" — ближайший прецедент, но без
      формальных stop-слов).

- [ ] **B2. Убрать шаг 2e, использовать free-form + escape-command (recommended)** — Полностью выкинуть
      AskUserQuestion из Loop. После ответа оркестратор просто печатает результат и возвращается в режим
      ожидания следующего сообщения от пользователя (как в обычном chat-режиме). Для Save and finish —
      специальная команда: пользователь вводит /save или /done, либо просто пустое сообщение. Плюсы:
      максимально естественный flow, ноль кликов, соответствует духу Wait for questions from the user
      (`SKILL.md:151`). Минусы: пользователю нужно знать escape-команду; Claude Code orchestrator не всегда
      корректно отрабатывает "ничего не делать и ждать" без AskUserQuestion — возможны сюрпризы в раннере.
      Встраивание: удалить 2e, переписать 2f в "next message → 2a, message starting with /save or /done →
      Phase 3". Явно добавить в правило "не дёргать AskUserQuestion в Loop, только в Init и Finalize".
      Evidence: `skills/explore/SKILL.md:151` (правило уже задекларировано, но 2e ему противоречит),
      `skills/fix/SKILL.md:280` (No stops. Work through to the end without confirmations between phases —
      прецедент убирать промежуточные подтверждения).

- [ ] **B3. Гибрид - первый вопрос через AskUserQuestion, дальше free-form** — На первом обороте
      (ITERATION == 0) показать меню как сейчас, чтобы донести инструкцию "следующий вопрос пиши в чат; чтобы
      сохранить — напиши /save". Со второго оборота — режим B2 без меню. Плюсы: baseline обучения
      пользователя + нулевой клик на дистанции. Минусы: две модели поведения в одном цикле, сложнее описывать
      в SKILL.md. Встраивание: в `SKILL.md:105` условие `if ITERATION == 0 → AskUserQuestion, else → free-form`.
      Evidence: `skills/task/SKILL.md:142-159` (прогрессивный паттерн clarifying questions в batch 1-4 с
      пересмотром Requirements между батчами).

- [ ] **B4. Periodic checkpoint вместо per-answer menu** — Меню 2e превращается в checkpoint каждые N
      вопросов (например, N=5 или при warning в 2f на 20+ вопросах). Между ними — чистый free-form. Плюсы:
      компромисс между B1 и B2 — пользователь всё равно иногда видит явный control, но не на каждом ответе.
      Минусы: надо выбирать N (магическое число), либо пользователь не знает когда меню всплывёт. Встраивание:
      объединить логику 2e и 2f (`SKILL.md:105-117`), добавить счётчик. Evidence: `SKILL.md:114-115` (2f уже
      содержит threshold-warning на 20 вопросов — логично доэкстендить его до checkpoint).

- [ ] **Other:** \_\_\_

### Key files

- `skills/explore/SKILL.md:60-117` — Loop Phase, где живёт шаг 2e с лишним меню и 2f с warning
- `skills/explore/SKILL.md:121-143` — Finalize Phase, куда встроится "Create issue" (A1)
- `skills/explore/SKILL.md:151` — правило "Wait for questions from the user", противоречащее 2e
- `skills/explore/agents/explore-agent.md:6` — read-only tools, нельзя добавить Write/Bash без пересмотра
- `skills/explore/agents/explore-log-writer.md:85` — правило "Do not commit", симметрично придётся задать для
  issue-writer
- `skills/pr/SKILL.md:99-101` — шаблон gh pr create в оркестраторе (основа для gh issue create в A1)
- `skills/pr/agents/pr-body-generator.md` — шаблон агента-синтезатора body (основа для explore-issue-writer)
- `skills/pr/agents/pr-data-collector.md:47-112` — gh auth status, label listing — нужные проверки для
  issue-пути
- `skills/task/SKILL.md:37` — единственное текущее использование gh issue view в yoke
- `skills/task/SKILL.md:263-273` — паттерн handoff-меню в конце скилла, шаблон для Phase 4 в A1
- `skills/review/SKILL.md:140-142` — прецедент gh api --method POST .../issues/.../comments (альтернативный
  low-level путь)
- `skills/fix/SKILL.md:36,280` — паттерн intent-parsing из $ARGUMENTS (для A4) и правило "No stops" (для B2)
- `skills/explore/reference/exploration-log-format.md` — формат markdown-лога, из которого issue-writer будет
  доставать материал
- `docs/explore.md:23` — расхождение: упоминает Phase 4 Complete с меню, которого нет в SKILL.md (Phase 4
  изначально планировалась)

---

## Summary

Сессия зафиксировала, что текущий `/yoke:explore` строго read-only: `explore-agent` без Write/Edit,
`explore-log-writer` пишет только локальный `docs/ai/<slug>/<slug>-exploration.md` без коммита, и во всём
yoke нет ни одного вызова `gh issue create`. Для улучшения "создание issue из сессии" самый чистый путь —
A1 (новая Phase 4 "Create issue?" после Finalize по шаблону `/yoke:pr` с `gh pr create` и отдельным
body-generator), опционально дополненный A2 для per-question зернистости. Для "убрать лишний клик" наиболее
здоровые варианты — B2 (полностью убрать AskUserQuestion из Loop, опираться на `/save` как escape) или B3
(гибрид, меню только на первом обороте); B1 хрупок из-за интернационализации stop-слов. Также найдено
расхождение между `docs/explore.md:23` и `SKILL.md` — Phase 4 изначально планировалась, но не реализована,
что снижает риск введения A1 как "восстановления задуманного поведения".
