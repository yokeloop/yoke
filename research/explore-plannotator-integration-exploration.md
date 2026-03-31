# Exploration: Интеграция с upstream plannotator через хуки вместо форка

**Дата:** 2026-03-31
**Вопросов:** 4

---

## Q1: Как устроен хук-плагин plannotator и можно ли интегрироваться с ним для task/review

Upstream plannotator hook перехватывает только ExitPlanMode (событие PermissionRequest) — не подходит для произвольного вызова после task/review. Но CLI поддерживает прямой вызов: `plannotator annotate <file.md>` — открывает UI в браузере, блокирует, возвращает feedback в stdout. Upstream slash-команды используют паттерн `!plannotator annotate $ARGUMENTS`. В sp уже есть review-artifact через sp-annotator. Два варианта: заменить sp-annotator на upstream plannotator или добавить хук (но Stop-хуки не знают какой скилл завершился).

**Key files:**

- `/home/heliotik/project/try/plannotator/apps/hook/hooks/hooks.json` — upstream hooks.json: PermissionRequest/ExitPlanMode хук
- `/home/heliotik/project/try/plannotator/apps/hook/server/index.ts:272-385` — annotate mode CLI
- `/home/heliotik/project/try/plannotator/apps/hook/commands/plannotator-annotate.md` — slash-команда: !plannotator annotate $ARGUMENTS
- `skills/task/SKILL.md:265-284` — Фаза 6 task: уже предлагает review-artifact

**Sources:**

- Upstream plannotator repository

---

## Q2: Детали Plan Mode + plannotator feedback flow

При ExitPlanMode plannotator получает через stdin JSON с полем tool_input.plan — текст плана из Plan Mode. При deny возвращает JSON с decision.behavior="deny" и decision.message содержащим все аннотации пользователя в markdown (через функцию planDenyFeedback). При approve аннотации теряются — ограничение Claude Code. EnterPlanMode/ExitPlanMode — нативные инструменты Claude, скилл не может их вызвать программно, но может инструктировать Claude. Task-скилл (фазы 3-5) несовместим с Plan Mode из-за Write/AskUserQuestion/Bash.

**Key files:**

- `/home/heliotik/project/try/plannotator/apps/hook/server/index.ts:750-786` — stdout output при approve и deny
- `/home/heliotik/project/try/plannotator/packages/server/index.ts:496-526` — /api/deny handler
- `/home/heliotik/project/try/plannotator/packages/shared/feedback-templates.ts:12-22` — planDenyFeedback

**Sources:**

- Upstream plannotator repository

---

## Q3: Двухфазный task: исследование + Plan Mode ревью

Подход подтверждён. Фазы 1-3 task-скилла (Parse, Investigate, Synthesize) не используют Write/Edit — только Read, Agent, AskUserQuestion, Bash. Формат task-файла (markdown) точно совпадает с форматом ExitPlanMode({ plan: "markdown" }). Двухфазный flow: (1) Поиск + сбор контекста в нормальном режиме → (2) EnterPlanMode с draft task → plannotator ревью → deny/правки/resubmit цикл → approve → (3) Write файл + Commit в нормальном режиме. Для ~90% правок (перефразировка, уточнение требований) повторное исследование кодовой базы не нужно.

**Key files:**

- `skills/task/SKILL.md:31-169` — фазы 1-3 (только read/agent/ask, нет write)
- `skills/task/SKILL.md:174-239` — фаза 4 write + формат task-файла
- `/home/heliotik/project/try/plannotator/apps/marketing/src/content/docs/guides/claude-code.md:1-68` — workflow Plan Mode + plannotator

**Sources:**

- Upstream plannotator documentation

---

## Q4: Финальный flow — подтверждение порядка фаз

Подтверждён трёхфазный порядок: (1) Поиск + сбор контекста (нормальный режим: Bash, Agent, Read, Glob, Grep, AskUserQuestion), (2) Plan Mode (EnterPlanMode → ExitPlanMode с draft task → plannotator UI → deny→правки→resubmit или approve→выход), (3) Финал (нормальный режим: Write файл, Copyedit, Commit, Notify). При deny в Plan Mode, если нужна фактическая проверка кода — выйти из Plan Mode, исследовать, войти обратно (редкий кейс).

**Key files:**

- `skills/task/SKILL.md` — весь файл, основа для рефакторинга

**Sources:**

- Task skill implementation

---

## Summary

Исследование подтвердило возможность интеграции upstream plannotator в sp через трёхфазный workflow. Plan Mode несовместим с фазами 3-5 task-скилла из-за инструментов с side effects, но фазы 1-3 (исследование) могут быть переработаны для план Mode. Ключевое преимущество: plannotator hook ExitPlanMode автоматически перехватывает выход из Plan Mode и открывает UI для ревью с полной поддержкой feedback loop (deny/правки/resubmit). Дальнейшие работы: рефакторить task-скилл на двухфазный workflow с явным EnterPlanMode/ExitPlanMode переходом после синтеза требований.
