# sp-annotator: Руководство по синхронизации с upstream

sp-annotator -- форк [plannotator](https://github.com/backnotprop/plannotator). Этот документ описывает маппинг директорий, правила трансформации и порядок синхронизации.

## Directory Mapping

| Upstream (plannotator)                  | Fork (packages/annotator/)      | Статус                                  |
| --------------------------------------- | ------------------------------- | --------------------------------------- |
| `packages/server/annotate.ts`           | `src/server/annotate.ts`        | Портирован                              |
| `packages/server/review.ts`             | `src/server/review.ts`          | Портирован                              |
| `packages/server/shared-handlers.ts`    | `src/server/shared-handlers.ts` | Портирован                              |
| `packages/server/remote.ts`             | `src/server/remote.ts`          | Портирован                              |
| `packages/server/browser.ts`            | `src/server/browser.ts`         | Портирован                              |
| `packages/server/image.ts`              | `src/server/image.ts`           | Портирован                              |
| `packages/server/draft.ts`              | `src/server/draft.ts`           | Портирован                              |
| `packages/server/repo.ts`               | `src/server/repo.ts`            | Портирован                              |
| `packages/server/git.ts`                | `src/server/git.ts`             | Портирован (thin wrapper)               |
| `packages/server/pr.ts`                 | `src/server/pr.ts`              | Портирован (thin wrapper)               |
| `packages/server/resolve-file.ts`       | `src/server/resolve-file.ts`    | Портирован                              |
| `packages/server/index.ts`              | --                              | НЕ портирован (plan server + hook)      |
| `packages/server/storage.ts`            | --                              | НЕ портирован (plan saving/versions)    |
| `packages/server/share-url.ts`          | --                              | НЕ портирован (paste service)           |
| `packages/server/integrations.ts`       | --                              | НЕ портирован (Obsidian/Bear)           |
| `packages/server/ide.ts`                | --                              | НЕ портирован (VS Code diff)            |
| `packages/server/editor-annotations.ts` | --                              | НЕ портирован (VS Code annotations)     |
| `packages/server/sessions.ts`           | --                              | НЕ портирован (session tracking)        |
| `packages/server/project.ts`            | --                              | НЕ портирован (project name detection)  |
| `packages/ai/`                          | `src/ai/`                       | Портирован                              |
| `packages/shared/storage.ts`            | --                              | НЕ портирован                           |
| `packages/shared/draft.ts`              | `src/server/draft.ts` (inline)  | Портирован                              |
| `packages/shared/project.ts`            | --                              | НЕ портирован                           |
| `packages/shared/` (остальное)          | `src/shared/`                   | Портирован                              |
| `packages/editor/`                      | `editor/`                       | Портирован                              |
| `packages/review-editor/`               | `review-editor/`                | Портирован                              |
| `packages/ui/`                          | `ui/`                           | Портирован                              |
| `apps/hook/`                            | --                              | НЕ портирован (Claude Code hook plugin) |
| `apps/review/`                          | `apps/review-app/`              | Портирован (переименован)               |
| `apps/opencode-plugin/`                 | --                              | НЕ портирован                           |
| `apps/vscode-extension/`                | --                              | НЕ портирован                           |
| `apps/paste-service/`                   | --                              | НЕ портирован                           |
| `apps/marketing/`                       | --                              | НЕ портирован                           |

## Import Path Transformations

В upstream используется монорепо с package-based imports. В fork все компоненты консолидированы в один пакет с путями через Vite aliases.

### Vite Aliases (сборка UI)

**plan-editor** (`apps/plan-editor/vite.config.ts`):

```
@plannotator/editor       → ../../editor/App.tsx
@plannotator/editor/styles → ../../editor/index.css
@plannotator/ui           → ../../ui
@plannotator/shared       → ../../src/shared
```

**review-app** (`apps/review-app/vite.config.ts`):

```
@plannotator/review-editor       → ../../review-editor/App.tsx
@plannotator/review-editor/styles → ../../review-editor/index.css
@plannotator/ui                  → ../../ui
@plannotator/ai                  → ../../src/ai
@plannotator/shared              → ../../src/shared
```

### Server Imports (Bun runtime)

Server-модули используют относительные пути напрямую:

```typescript
// Upstream: import { ... } from "@plannotator/shared/storage"
// Fork:    import { ... } from "../shared/review-core"

// Upstream: import { ... } from "@plannotator/server/git"
// Fork:    import { ... } from "./git"
```

Серверные модули `git.ts` и `pr.ts` -- thin wrappers: runtime-зависимый код (Bun.spawn, Bun.file) в них, core-логика в `src/shared/review-core.ts` и `src/shared/pr-provider.ts`.

## Правила ребрендинга

### Что переименовано

- Package name: `plannotator` → `@sp/annotator`
- CLI binary: `plannotator` → `sp-annotator`
- UI title: "Plannotator" → "sp-annotator" (в отображении UI)

### Что НЕ переименовано (и не нужно)

- Env vars: `PLANNOTATOR_REMOTE`, `PLANNOTATOR_PORT`, `PLANNOTATOR_BROWSER` -- сохранены для совместимости с upstream
- Import aliases: `@plannotator/ui`, `@plannotator/editor`, `@plannotator/shared` -- используются только внутри Vite resolve, не видны пользователю
- Internal identifiers: имена функций `startAnnotateServer`, `startReviewServer` -- не требуют ребрендинга
- NPM packages: `@plannotator/web-highlighter` -- внешняя зависимость

### Правило: не ребрендить внутренние имена

Ребрендинг ограничен пользовательски-видимыми элементами (CLI name, package name, UI labels). Внутренние идентификаторы, env vars и import aliases сохранены для минимизации diff при синхронизации с upstream.

## SP-Specific код (не перезаписывать)

Эти файлы содержат SP-специфичные изменения, которые НЕ должны перезаписываться при синхронизации:

| Файл                              | Причина                                                           |
| --------------------------------- | ----------------------------------------------------------------- |
| `package.json`                    | Имя `@sp/annotator`, SP-специфичные scripts                       |
| `src/cli.ts`                      | CLI entry point адаптирован для sp (3 standalone режима без hook) |
| `apps/plan-editor/vite.config.ts` | Пути aliases адаптированы под структуру fork                      |
| `apps/review-app/vite.config.ts`  | Пути aliases адаптированы под структуру fork                      |
| `apps/plan-editor/index.html`     | Заголовок "sp-annotator"                                          |
| `apps/review-app/index.html`      | Заголовок "sp-annotator"                                          |

## Порядок синхронизации

При обновлении из upstream:

### 1. Сравнить upstream изменения

```bash
# В директории upstream (plannotator)
cd /path/to/plannotator
git log --oneline HEAD~10..HEAD
git diff HEAD~N..HEAD -- packages/server/ packages/ai/ packages/shared/ packages/editor/ packages/review-editor/ packages/ui/
```

### 2. Применить изменения по категориям

**Безопасное копирование (1:1 маппинг):**

- `packages/ai/*` → `src/ai/*`
- `packages/shared/*` → `src/shared/*` (кроме `storage.ts`, `project.ts`, `draft.ts`)
- `packages/ui/*` → `ui/*`
- `packages/editor/App.tsx` → `editor/App.tsx`
- `packages/review-editor/*` → `review-editor/*`

**Ручное слияние (содержат SP-специфичный код):**

- `packages/server/annotate.ts` → `src/server/annotate.ts` (diff + merge)
- `packages/server/review.ts` → `src/server/review.ts` (diff + merge)
- `packages/server/shared-handlers.ts` → `src/server/shared-handlers.ts` (diff + merge)

**Пропустить:**

- `packages/server/index.ts` (plan server hook -- не используется)
- `packages/server/storage.ts` (plan saving -- не используется)
- `packages/server/share-url.ts` (paste service -- не используется)
- `packages/server/integrations.ts` (Obsidian/Bear -- не используется)
- `packages/server/ide.ts` (VS Code diff -- не используется)
- `packages/server/editor-annotations.ts` (VS Code annotations -- не используется)
- `apps/hook/` (hook plugin -- не используется)
- `apps/vscode-extension/` (VS Code extension -- не используется)
- `apps/paste-service/` (paste service -- не используется)
- `apps/marketing/` (marketing site -- не используется)

### 3. Адаптировать import paths

После копирования файлов, проверить и исправить import paths:

```bash
# Найти сломанные импорты
cd packages/annotator
grep -r "@plannotator/server" src/    # Заменить на относительные пути
grep -r "from '\.\./\.\./shared" src/ # Проверить относительные пути
```

### 4. Пересобрать и проверить

```bash
cd packages/annotator
bun install
bun run build
```

### 5. Протестировать

```bash
./bin/sp-annotator annotate ../../../README.md
./bin/sp-annotator diff
```

## Slug Fix (DD-5)

В upstream есть фикс slug-генерации для permalink URL. Этот фикс НЕ ПРИМЕНИМ к SP fork:

- SP fork не использует plan server с hook-интеграцией
- SP fork не сохраняет планы в архив (`~/.plannotator/plans/`)
- Permalink URL и slug-генерация не задействованы

Ссылка: DD-5 в upstream issue tracker.

## Не портированные фичи (future work)

### GitHub Viewed Files Sync

- **Upstream**: hook plugin помечает файлы как "viewed" в GitHub PR при просмотре в review UI
- **Статус**: НЕ ПОРТИРОВАН
- **Причина**: требует hook-интеграцию (`apps/hook/`), которая не используется в sp-annotator
- **Путь реализации**: потребуется интеграция с sp hook system или отдельный механизм

### Archive Browsing UI

- **Upstream**: компонент `ArchiveBrowser` в sidebar для просмотра сохраненных планов из `~/.plannotator/plans/`
- **Статус**: НЕ ПОРТИРОВАН
- **Причина**: sp-annotator не сохраняет планы в архив, нет `storage.ts`
- **Путь реализации**: потребуется реализация storage layer и адаптация ArchiveBrowser
