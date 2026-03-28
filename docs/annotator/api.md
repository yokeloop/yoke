# sp-annotator: HTTP API

sp-annotator запускает локальный HTTP-сервер (Bun.serve) для обслуживания UI и обработки пользовательских действий. API зависит от режима: annotate server обслуживает annotate и review, review server обслуживает diff.

## Annotate Server

Сервер: `src/server/annotate.ts` -- `startAnnotateServer()`.
Используется для режимов `annotate` и `review`.

### GET /api/plan

Возвращает markdown-контент для отображения в plan editor UI.

**Response:**

```json
{
  "plan": "# Markdown content...",
  "origin": "claude-code",
  "mode": "annotate",
  "filePath": "/absolute/path/to/file.md",
  "sharingEnabled": true,
  "shareBaseUrl": null,
  "repoInfo": {
    "display": "owner/repo",
    "branch": "feature-branch"
  }
}
```

Поля:

- `plan` -- содержимое markdown-файла
- `origin` -- идентификатор клиента (`"claude-code"`, `"opencode"`, `"pi"`, `"codex"`)
- `mode` -- `"annotate"` (файл) или `"annotate-last"` (последнее сообщение агента)
- `filePath` -- абсолютный путь к файлу
- `sharingEnabled` -- включено ли расшаривание URL
- `repoInfo` -- информация о репозитории (display name, текущая ветка)

### POST /api/feedback

Отправка результата аннотирования. Закрывает сервер.

**Request:**

```json
{
  "feedback": "Текст общего фидбека",
  "annotations": [
    {
      "text": "Выделенный текст",
      "comment": "Комментарий к аннотации",
      "type": "comment"
    }
  ]
}
```

**Response:**

```json
{ "ok": true }
```

### GET /api/doc

Отдает содержимое связанного markdown-документа. Автоматически подставляет `base` из директории текущего файла для относительных путей.

**Query params:**

- `path` -- путь к документу (абсолютный или относительный)
- `base` -- базовая директория для относительных путей (устанавливается автоматически)

**Response:** содержимое markdown-файла (text)

## Review Server

Сервер: `src/server/review.ts` -- `startReviewServer()`.
Используется для режима `diff`.

### GET /api/diff

Возвращает diff-контент для отображения в review UI.

**Response (локальный режим):**

```json
{
  "rawPatch": "diff --git a/file.ts b/file.ts\n...",
  "gitRef": "uncommitted changes",
  "origin": "claude-code",
  "diffType": "uncommitted",
  "gitContext": {
    "currentBranch": "feature-branch",
    "defaultBranch": "main",
    "cwd": "/path/to/repo",
    "diffOptions": [
      { "type": "uncommitted", "label": "Uncommitted" },
      { "type": "staged", "label": "Staged" },
      { "type": "branch", "label": "vs main" }
    ],
    "worktrees": []
  },
  "sharingEnabled": true,
  "repoInfo": {
    "display": "owner/repo",
    "branch": "feature-branch"
  }
}
```

**Response (PR режим):**

```json
{
  "rawPatch": "diff --git a/file.ts b/file.ts\n...",
  "gitRef": "PR #123",
  "origin": "claude-code",
  "sharingEnabled": true,
  "repoInfo": {
    "display": "owner/repo",
    "branch": "PR #123"
  },
  "prMetadata": {
    "url": "https://github.com/owner/repo/pull/123",
    "title": "PR title",
    "body": "PR description",
    "baseSha": "abc123",
    "headSha": "def456",
    "author": "username",
    "state": "open"
  },
  "platformUser": "current-user"
}
```

### POST /api/diff/switch

Переключение типа diff. Недоступен в PR-режиме.

**Request:**

```json
{
  "diffType": "staged"
}
```

Допустимые значения `diffType`: `"uncommitted"`, `"staged"`, `"branch"`, `"worktree:<path>"`.

**Response:**

```json
{
  "rawPatch": "diff --git ...",
  "gitRef": "staged changes",
  "diffType": "staged"
}
```

### GET /api/pr-context

Контекст PR: комментарии, checks, merge status. Только в PR-режиме.

**Response:** JSON с информацией о комментариях, статусе checks и возможности merge.

### GET /api/file-content

Полное содержимое файла для expandable diff context.

**Query params:**

- `path` -- путь к файлу
- `oldPath` -- старый путь (для переименованных файлов, опционально)

**Response (локальный режим):**

```json
{
  "oldContent": "содержимое файла в базовой версии или null",
  "newContent": "текущее содержимое файла или null"
}
```

**Response (PR режим):** содержимое берется с платформы (GitHub/GitLab) по baseSha/headSha.

### POST /api/git-add

Stage или unstage файла. Недоступен в PR-режиме.

**Request:**

```json
{
  "filePath": "src/file.ts",
  "undo": false
}
```

- `undo: false` -- `git add <file>`
- `undo: true` -- `git reset <file>`

**Response:**

```json
{ "ok": true }
```

### POST /api/pr-action

Отправка review на GitHub/GitLab. Только в PR-режиме.

**Request:**

```json
{
  "action": "approve",
  "body": "LGTM! Good changes.",
  "fileComments": [
    {
      "path": "src/file.ts",
      "line": 42,
      "body": "Consider renaming this variable"
    }
  ]
}
```

- `action` -- `"approve"` или `"comment"`
- `body` -- текст review
- `fileComments` -- inline-комментарии к файлам

**Response:**

```json
{
  "ok": true,
  "prUrl": "https://github.com/owner/repo/pull/123"
}
```

### POST /api/feedback

Отправка review feedback. Закрывает сервер.

**Request:**

```json
{
  "approved": true,
  "feedback": "",
  "annotations": []
}
```

Или:

```json
{
  "approved": false,
  "feedback": "Текст фидбека с аннотациями",
  "annotations": [
    {
      "text": "diff fragment",
      "comment": "Issue description"
    }
  ]
}
```

**Response:**

```json
{ "ok": true }
```

## Shared Endpoints

Доступны на обоих серверах. Реализованы в `src/server/shared-handlers.ts`.

### GET /api/image

Отдает локальное изображение по пути.

**Query params:**

- `path` -- абсолютный путь к изображению или путь в temp uploads
- `base` -- базовая директория для относительных путей (опционально)

**Response:** файл изображения с соответствующим Content-Type.

**Ошибки:**

- 400 -- Missing path parameter
- 403 -- Invalid path (валидация безопасности)
- 404 -- File not found

### POST /api/upload

Загрузка изображения во временную директорию.

**Request:** `multipart/form-data` с полем `file`.

**Response:**

```json
{
  "path": "/tmp/plannotator-uploads/uuid.png",
  "originalName": "screenshot.png"
}
```

**Ошибки:**

- 400 -- No file provided / Invalid extension

### GET /api/draft

Загрузка сохраненного черновика аннотаций.

**Response (найден):**

```json
{
  "feedback": "...",
  "annotations": [...]
}
```

**Response (не найден):**

```json
{ "found": false }
```

Status: 404

### POST /api/draft

Сохранение черновика аннотаций. Ключ -- content hash исходного контента (markdown или diff patch).

**Request:** JSON body с данными аннотаций.

**Response:**

```json
{ "ok": true }
```

### DELETE /api/draft

Удаление черновика.

**Response:**

```json
{ "ok": true }
```

### POST /api/config

Сохранение пользовательских настроек.

**Request:** JSON body с настройками.

**Response:**

```json
{ "ok": true }
```

## AI Endpoints

Доступны только на review server (diff mode). Реализованы в `src/ai/endpoints.ts` через `createAIEndpoints()`.
Если AI-провайдер (Claude Agent SDK) недоступен, эндпоинты не регистрируются.

### GET /api/ai/capabilities

Проверка доступности AI-функций.

**Response:**

```json
{
  "available": true,
  "providers": [
    {
      "id": "claude-agent-sdk-0",
      "name": "Claude Agent SDK",
      "capabilities": { "fork": true, "streaming": true },
      "models": []
    }
  ],
  "defaultProvider": "claude-agent-sdk-0"
}
```

### POST /api/ai/session

Создание новой AI-сессии.

**Request:**

```json
{
  "context": {
    "mode": "code-review",
    "content": "diff content...",
    "parent": null
  },
  "model": null,
  "maxTurns": null,
  "maxBudgetUsd": null,
  "reasoningEffort": "medium"
}
```

Поля `context.mode`: `"plan"`, `"code-review"`, `"annotate"`.

**Response:**

```json
{
  "sessionId": "session-uuid",
  "parentSessionId": null,
  "mode": "code-review",
  "createdAt": "2026-03-28T12:00:00.000Z"
}
```

### POST /api/ai/query

Отправка запроса к AI. Ответ приходит как SSE stream.

**Request:**

```json
{
  "sessionId": "session-uuid",
  "prompt": "Explain this change",
  "contextUpdate": null
}
```

**Response:** `text/event-stream` (Server-Sent Events)

Формат событий:

```
data: {"type":"text_delta","text":"Partial response..."}

data: {"type":"text","text":"Full accumulated text"}

data: {"type":"tool_use","tool":"Read","input":{"path":"/file.ts"}}

data: {"type":"tool_result","tool":"Read","output":"file contents..."}

data: {"type":"result","text":"Final answer","cost":{"input":100,"output":50},"duration":1234}

data: {"type":"error","error":"Something went wrong","code":"stream_error"}

data: [DONE]
```

Типы сообщений (`type`):

- `text_delta` -- инкрементальный фрагмент текста
- `text` -- полный накопленный текст
- `tool_use` -- вызов инструмента
- `tool_result` -- результат инструмента
- `permission_request` -- запрос разрешения
- `result` -- финальный результат
- `error` -- ошибка

### POST /api/ai/abort

Отмена текущего AI-запроса.

**Request:**

```json
{
  "sessionId": "session-uuid"
}
```

**Response:**

```json
{ "ok": true }
```

### POST /api/ai/permission

Ответ на permission request от AI-агента.

**Request:**

```json
{
  "sessionId": "session-uuid",
  "requestId": "perm-uuid",
  "allow": true,
  "message": "Optional explanation"
}
```

**Response:**

```json
{ "ok": true }
```

### GET /api/ai/sessions

Список всех активных AI-сессий.

**Response:**

```json
[
  {
    "sessionId": "session-uuid",
    "mode": "code-review",
    "parentSessionId": null,
    "createdAt": "2026-03-28T12:00:00.000Z",
    "lastActiveAt": "2026-03-28T12:05:00.000Z",
    "isActive": true,
    "label": "Explain the diff in file.ts"
  }
]
```

## CLI JSON Output

Результат работы CLI выводится в stdout как JSON.

### Annotate mode

```json
{
  "mode": "annotate",
  "file": "/absolute/path/to/file.md",
  "feedback": "General feedback text",
  "annotations": []
}
```

### Review mode

```json
{
  "mode": "review",
  "action": "approved",
  "file": "/absolute/path/to/file.md",
  "annotations": [],
  "globalComments": [],
  "formattedFeedback": ""
}
```

`action` -- `"approved"` (нет feedback и аннотаций) или `"feedback"`.

### Diff mode

```json
{
  "mode": "diff",
  "action": "approved",
  "feedback": "",
  "annotations": []
}
```

Или:

```json
{
  "mode": "diff",
  "action": "feedback",
  "feedback": "Issues found in the diff",
  "annotations": [
    {
      "text": "diff fragment",
      "comment": "Description"
    }
  ]
}
```
