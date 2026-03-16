# Commit Convention

Правила коммитов. Conventional Commits, scope = slug задачи.

---

## Формат

```
<type>(<slug>): <описание>
```

Описание — на языке plan-файла. Краткое, одно предложение.

---

## Типы по этапам pipeline

| Этап | Тип | Пример |
|---|---|---|
| Task: реализация фичи | `feat` | `feat(rsa-44): SSE endpoint` |
| Task: тесты | `test` | `test(rsa-44): SSE and client tests` |
| Task: validation из плана | `chore` | `chore(rsa-44): validation` |
| Simplify | `refactor` | `refactor(rsa-44): simplify` |
| Cleanup | `chore` | `chore(rsa-44): cleanup` |
| Validate fix | `fix` | `fix(rsa-44): fix lint errors` |
| Documentation | `docs` | `docs(rsa-44): update documentation` |
| Format | `chore` | `chore(rsa-44): format` |

---

## Правила

- Один коммит на один этап. Не объединять.
- Slug берётся из plan-файла (из пути `docs/ai/<slug>/`).
- Не использовать `wip`, `temp`, `misc`.
- Если task содержит и реализацию и тесты — `feat` (тесты вместе с фичей).
- Если task только тесты — `test`.
