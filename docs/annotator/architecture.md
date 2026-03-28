# sp-annotator: Архитектура

Пакет `packages/annotator/` -- форк [plannotator](https://github.com/backnotprop/plannotator) (MIT OR Apache-2.0), адаптированный как standalone CLI-инструмент для плагина sp.

## Структура директорий

```
packages/annotator/
├── apps/
│   ├── plan-editor/              # Vite-приложение для annotate/review режимов
│   │   ├── index.html            # Entry point (React)
│   │   ├── index.tsx             # React mount
│   │   ├── vite.config.ts        # Vite + singlefile + Tailwind
│   │   └── dist/
│   │       ├── index.html        # Собранный single-file HTML (plan editor)
│   │       └── review.html       # Копия review-app/dist/index.html
│   └── review-app/               # Vite-приложение для diff режима
│       ├── index.html            # Entry point (React)
│       ├── index.tsx             # React mount
│       ├── vite.config.ts        # Vite + singlefile + Tailwind
│       └── dist/
│           └── index.html        # Собранный single-file HTML (review editor)
├── bin/
│   └── sp-annotator              # Скомпилированный Bun binary
├── editor/                       # Plan editor React-приложение
│   ├── App.tsx                   # Основной компонент (~65KB)
│   ├── demoPlan.ts               # Демо-данные для standalone режима
│   └── index.css                 # Стили plan editor
├── review-editor/                # Code review React-приложение
│   ├── App.tsx                   # Основной компонент (~71KB)
│   ├── components/               # DiffViewer, FileTree, ReviewPanel и др.
│   ├── hooks/                    # React hooks для review UI
│   ├── utils/                    # Утилиты review editor
│   ├── demoData.ts               # Демо diff для standalone режима
│   ├── index.css                 # Стили review editor
│   └── types.ts                  # Типы review editor
├── ui/                           # Shared React-компоненты и тема
│   ├── theme.css                 # CSS-токены цветов, Tailwind-bridge
│   ├── types.ts                  # Общие типы UI
│   ├── components/               # Viewer, Toolbar, Settings и др.
│   ├── hooks/                    # useAnnotationHighlighter, useSidebar и др.
│   ├── utils/                    # parser, sharing, storage, planDiffEngine
│   ├── themes/                   # Темы оформления
│   └── config/                   # Конфигурация UI
├── src/
│   ├── cli.ts                    # CLI entry point (3 режима)
│   ├── server/                   # HTTP-серверы (Bun.serve)
│   │   ├── annotate.ts           # startAnnotateServer()
│   │   ├── review.ts             # startReviewServer()
│   │   ├── shared-handlers.ts    # Общие handlers (/api/image, /api/upload, /api/draft, /api/config)
│   │   ├── git.ts                # Git операции (diff, add, reset)
│   │   ├── pr.ts                 # PR/MR операции (GitHub/GitLab)
│   │   ├── browser.ts            # Открытие браузера
│   │   ├── remote.ts             # Детекция remote-сессий, конфигурация порта
│   │   ├── resolve-file.ts       # Умный поиск markdown-файлов
│   │   ├── repo.ts               # Определение имени репозитория
│   │   ├── image.ts              # Валидация путей к изображениям
│   │   ├── draft.ts              # Персистенция черновиков аннотаций
│   │   └── doc.ts                # Обработка связанных markdown-документов
│   ├── ai/                       # AI-интеграция (provider-agnostic)
│   │   ├── index.ts              # Re-exports всех AI-компонентов
│   │   ├── types.ts              # Типы: AIProvider, AISession, AIMessage, AIContext
│   │   ├── provider.ts           # ProviderRegistry, createProvider()
│   │   ├── session-manager.ts    # SessionManager (отслеживание AI-сессий)
│   │   ├── base-session.ts       # BaseSession (абстрактный класс)
│   │   ├── context.ts            # buildSystemPrompt(), buildForkPreamble()
│   │   ├── endpoints.ts          # createAIEndpoints() -- HTTP handlers для AI
│   │   └── providers/
│   │       └── claude-agent-sdk.ts   # Провайдер через @anthropic-ai/claude-agent-sdk
│   └── shared/                   # Кроссплатформенная логика (shared с UI)
│       ├── review-core.ts        # Git diff core (runtime-agnostic)
│       ├── pr-provider.ts        # PR/MR core (runtime-agnostic)
│       ├── pr-github.ts          # GitHub API через gh CLI
│       ├── pr-gitlab.ts          # GitLab API через glab CLI
│       ├── config.ts             # Сохранение пользовательских настроек
│       ├── favicon.ts            # SVG favicon
│       ├── types.ts              # Общие типы
│       ├── crypto.ts             # Хеширование
│       ├── compress.ts           # Сжатие данных
│       ├── feedback-templates.ts # Шаблоны фидбека
│       ├── integrations-common.ts # Общие интеграции
│       └── reference-common.ts   # Общие reference-утилиты
└── package.json                  # @sp/annotator, Bun-ориентированная сборка
```

## Три CLI-режима

CLI `sp-annotator` (файл `src/cli.ts`) реализует три режима работы:

### 1. Annotate -- аннотирование markdown-файлов

```
sp-annotator annotate <file.md>
```

- Открывает markdown-файл в plan editor UI
- Пользователь добавляет аннотации и feedback
- Выводит JSON в stdout: `{ mode, file, feedback, annotations }`
- Сервер: `startAnnotateServer()` из `src/server/annotate.ts`
- UI: plan-editor HTML (встраивается при компиляции)

### 2. Review -- ревью markdown с approve/feedback

```
sp-annotator review <file.md> [--previous <old.md>]
```

- Открывает markdown-файл с кнопками Approve/Feedback
- Различает approve (нет аннотаций и feedback) от feedback
- Выводит JSON в stdout: `{ mode, action, file, annotations, globalComments, formattedFeedback }`
- Сервер: `startAnnotateServer()` (тот же, что и для annotate)
- UI: plan-editor HTML

### 3. Diff -- code review по git diff или PR

```
sp-annotator diff [PR-URL]
```

- Без URL: локальный git diff (uncommitted изменения)
- С URL: PR/MR review (GitHub `https://github.com/owner/repo/pull/N`, GitLab `https://gitlab.com/.../merge_requests/N`)
- Выводит JSON в stdout: `{ mode, action, feedback, annotations }`
- Сервер: `startReviewServer()` из `src/server/review.ts`
- UI: review-app HTML (встраивается при компиляции)

## Data Flow

### Annotate / Review

```
CLI (src/cli.ts)
  │
  ├── resolveMarkdownFile(filePath, cwd)    # Умный поиск файла
  ├── Bun.file(path).text()                 # Чтение markdown
  │
  └── startAnnotateServer({markdown, filePath, htmlContent, origin})
       │
       ├── Bun.serve() на случайном порту
       │   ├── GET  /api/plan      → { plan: markdown, origin, mode, filePath, repoInfo }
       │   ├── GET  /api/image     → Локальные изображения
       │   ├── GET  /api/doc       → Связанные markdown-документы
       │   ├── POST /api/upload    → Загрузка изображений
       │   ├── */   /api/draft     → Автосохранение аннотаций
       │   ├── POST /api/feedback  → Отправка результата → resolveDecision()
       │   ├── POST /api/config    → Сохранение настроек пользователя
       │   └── *    /              → SPA HTML (single-file)
       │
       ├── openBrowser(url)
       └── waitForDecision() → JSON → stdout
```

### Diff

```
CLI (src/cli.ts)
  │
  ├── [PR mode]  parsePRUrl() → checkAuth() → fetchPR() → rawPatch
  ├── [Local]    getGitContext() → runGitDiff("uncommitted") → rawPatch
  │
  └── startReviewServer({rawPatch, gitRef, htmlContent, origin, gitContext, prMetadata})
       │
       ├── AI Provider Setup (graceful degradation)
       │   ├── ProviderRegistry + SessionManager
       │   └── createProvider({type: "claude-agent-sdk"}) → register
       │
       ├── Bun.serve() на случайном порту
       │   ├── GET  /api/diff          → { rawPatch, gitRef, origin, diffType, gitContext, repoInfo }
       │   ├── POST /api/diff/switch   → Переключение типа diff (uncommitted/staged/branch)
       │   ├── GET  /api/pr-context    → Комментарии, checks, merge status (PR mode)
       │   ├── GET  /api/file-content  → Полное содержимое файлов для expandable diff
       │   ├── POST /api/git-add       → git add/reset файлов
       │   ├── POST /api/pr-action     → Отправка review на GitHub/GitLab
       │   ├── POST /api/ai/session    → Создание AI-сессии
       │   ├── POST /api/ai/query      → Запрос к AI (SSE stream)
       │   ├── POST /api/ai/abort      → Отмена текущего запроса
       │   ├── GET  /api/ai/sessions   → Список активных сессий
       │   ├── GET  /api/ai/capabilities → Проверка доступности AI
       │   ├── POST /api/ai/permission → Ответ на permission request
       │   └── [shared endpoints: /api/image, /api/upload, /api/draft, /api/config, /api/feedback]
       │
       ├── openBrowser(url)
       └── waitForDecision() → JSON → stdout
```

## Server Modules

| Модуль                      | Ответственность                                                                                                        |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `server/annotate.ts`        | Bun-сервер для annotate/review. Отдает markdown через `/api/plan`, принимает feedback через `/api/feedback`            |
| `server/review.ts`          | Bun-сервер для code review. Отдает diff через `/api/diff`, поддерживает переключение diff type, PR mode, AI-интеграцию |
| `server/shared-handlers.ts` | Общие handlers: `/api/image`, `/api/upload`, `/api/draft` (save/load/delete), `/api/config`, favicon                   |
| `server/git.ts`             | Git операции через Bun.spawn. Thin wrapper над `shared/review-core.ts` с Bun-рантаймом                                 |
| `server/pr.ts`              | PR/MR операции через gh/glab CLI. Thin wrapper над `shared/pr-provider.ts`                                             |
| `server/browser.ts`         | Открытие URL в браузере (platform-aware)                                                                               |
| `server/remote.ts`          | Определение remote-сессии (SSH, devcontainer). Env: `PLANNOTATOR_REMOTE`, `PLANNOTATOR_PORT`                           |
| `server/resolve-file.ts`    | Умный поиск markdown-файлов: absolute path, relative path, case-insensitive filename search                            |
| `server/repo.ts`            | Определение имени репозитория для display                                                                              |
| `server/image.ts`           | Валидация путей к изображениям, UPLOAD_DIR                                                                             |
| `server/draft.ts`           | Персистенция черновиков аннотаций на диске                                                                             |
| `server/doc.ts`             | Обработка связанных markdown-документов (`/api/doc`)                                                                   |

## UI Layers

Две React-приложения, собираемые Vite в single-file HTML:

### plan-editor (annotate + review)

- **Entry**: `apps/plan-editor/index.tsx` → `editor/App.tsx`
- **Vite aliases**: `@plannotator/editor` → `editor/App.tsx`, `@plannotator/ui` → `ui/`, `@plannotator/shared` → `src/shared/`
- **Dev port**: 3000
- **Компоненты**: markdown viewer, annotation toolbar, settings
- **Shared UI**: `ui/components/`, `ui/hooks/`, `ui/utils/`

### review-app (diff)

- **Entry**: `apps/review-app/index.tsx` → `review-editor/App.tsx`
- **Vite aliases**: `@plannotator/review-editor` → `review-editor/App.tsx`, `@plannotator/ui` → `ui/`, `@plannotator/ai` → `src/ai/`, `@plannotator/shared` → `src/shared/`
- **Dev port**: 3001
- **Компоненты**: diff viewer, file tree, review panel, AI chat
- **Shared UI**: `ui/components/`, `ui/hooks/`, `ui/utils/`

Оба приложения используют:

- React 19 + Tailwind CSS 4
- `vite-plugin-singlefile` для инлайна всех ассетов в один HTML
- Shared тему из `ui/theme.css`

## AI Integration

AI-функции доступны только в review-app (diff mode).

```
UI (review-editor)
  ↓ HTTP
/api/ai/session (POST)     → SessionManager.track(session)
/api/ai/query   (POST)     → session.query(prompt) → SSE stream
/api/ai/abort   (POST)     → session.abort()
/api/ai/capabilities (GET) → Список провайдеров
/api/ai/sessions (GET)     → Список активных сессий
/api/ai/permission (POST)  → Ответ на permission request
  ↓
SessionManager → AISession
  ↓
AIProvider (abstract)
  ↓
ClaudeAgentSDKProvider (через @anthropic-ai/claude-agent-sdk)
```

- **Провайдер**: Claude Agent SDK (`claude` CLI должен быть доступен)
- **Graceful degradation**: если SDK недоступен, AI-кнопки скрыты
- **Streaming**: SSE (Server-Sent Events) для потоковых ответов
- **Forking**: поддержка fork-сессий (если провайдер поддерживает)

## Directory Mapping: Upstream -> Fork

| Upstream (plannotator)                  | Fork (sp-annotator)             | Примечание                              |
| --------------------------------------- | ------------------------------- | --------------------------------------- |
| `packages/server/index.ts`              | --                              | Не портирован (plan server с hook)      |
| `packages/server/annotate.ts`           | `src/server/annotate.ts`        | Standalone annotate server              |
| `packages/server/review.ts`             | `src/server/review.ts`          | Standalone review server                |
| `packages/server/shared-handlers.ts`    | `src/server/shared-handlers.ts` | Общие HTTP handlers                     |
| `packages/server/remote.ts`             | `src/server/remote.ts`          | Remote detection                        |
| `packages/server/browser.ts`            | `src/server/browser.ts`         | Browser open                            |
| `packages/server/image.ts`              | `src/server/image.ts`           | Image validation                        |
| `packages/server/draft.ts`              | `src/server/draft.ts`           | Draft persistence                       |
| `packages/server/repo.ts`               | `src/server/repo.ts`            | Repo info                               |
| `packages/server/storage.ts`            | --                              | Не портирован (plan saving)             |
| `packages/server/share-url.ts`          | --                              | Не портирован (paste service)           |
| `packages/server/integrations.ts`       | --                              | Не портирован (Obsidian/Bear)           |
| `packages/server/ide.ts`                | --                              | Не портирован (VS Code diff)            |
| `packages/server/editor-annotations.ts` | --                              | Не портирован (VS Code annotations)     |
| `packages/server/sessions.ts`           | --                              | Не портирован (session tracking)        |
| `packages/server/project.ts`            | --                              | Не портирован (project name)            |
| `packages/ai/`                          | `src/ai/`                       | AI backbone (полностью портирован)      |
| `packages/shared/`                      | `src/shared/`                   | Shared types и утилиты                  |
| `packages/editor/`                      | `editor/`                       | Plan editor App.tsx                     |
| `packages/review-editor/`               | `review-editor/`                | Review editor App.tsx                   |
| `packages/ui/`                          | `ui/`                           | Shared React UI                         |
| `apps/hook/`                            | --                              | Не портирован (Claude Code hook plugin) |
| `apps/review/`                          | `apps/review-app/`              | Standalone review dev server            |

## Не портированные компоненты

- **GitHub viewed files sync** -- НЕ ПОРТИРОВАН. Фича upstream hook plugin, помечающая файлы как viewed в PR. Требует hook-интеграцию. Future work.
- **Archive browsing UI** -- НЕ ПОРТИРОВАН. ArchiveBrowser для просмотра сохраненных планов. Компонент `ArchiveBrowser` отсутствует в fork. Future work.
- **Plan server hook** (`packages/server/index.ts`) -- НЕ ПОРТИРОВАН. PermissionRequest hook для перехвата ExitPlanMode. В sp-annotator используется CLI вместо hook.
- **VS Code extension** (`apps/vscode-extension/`) -- НЕ ПОРТИРОВАН.
- **Paste service** (`apps/paste-service/`) -- НЕ ПОРТИРОВАН.
- **Marketing site** (`apps/marketing/`) -- НЕ ПОРТИРОВАН.
