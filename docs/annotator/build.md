# sp-annotator: Сборка

## Prerequisites

- **Bun** >= 1.0 (runtime + bundler + package manager)
- **Node.js** >= 18 (для Vite dev server)

Bun используется как:

- Package manager (`bun install`)
- Bundler (`bun build --compile`)
- Runtime (серверы на `Bun.serve()`, файловые операции через `Bun.file()`)

## Установка зависимостей

```bash
cd packages/annotator
bun install
```

Ключевые зависимости:

| Пакет                                    | Назначение                         |
| ---------------------------------------- | ---------------------------------- |
| `react`, `react-dom` (^19)               | UI                                 |
| `@anthropic-ai/claude-agent-sdk`         | AI-провайдер                       |
| `@pierre/diffs`                          | Парсинг unified diff               |
| `@plannotator/web-highlighter`           | Подсветка аннотаций                |
| `mermaid`                                | Рендер mermaid-диаграмм в markdown |
| `highlight.js`                           | Подсветка синтаксиса кода          |
| `marked`                                 | Парсинг markdown                   |
| `dompurify`                              | Санитизация HTML                   |
| `vite` + `vite-plugin-singlefile`        | Сборка single-file HTML            |
| `tailwindcss` + `@tailwindcss/vite` (^4) | CSS                                |

## Сборка

Полная сборка выполняется в 3 этапа:

```bash
bun run build
```

Это последовательно запускает:

### 1. `build:review` -- Сборка review-app

```bash
cd apps/review-app && vite build
```

- Собирает `review-editor/App.tsx` в single-file HTML
- Результат: `apps/review-app/dist/index.html` (~12MB)
- Vite aliases: `@plannotator/review-editor` → `review-editor/App.tsx`, `@plannotator/ai` → `src/ai/`, `@plannotator/shared` → `src/shared/`

### 2. `build:plan` -- Сборка plan-editor

```bash
cd apps/plan-editor && vite build && cp ../review-app/dist/index.html dist/review.html
```

- Собирает `editor/App.tsx` в single-file HTML
- Копирует review HTML для встраивания в бинарник
- Результат: `apps/plan-editor/dist/index.html` (~7.7MB), `apps/plan-editor/dist/review.html` (~12MB)
- Vite aliases: `@plannotator/editor` → `editor/App.tsx`, `@plannotator/shared` → `src/shared/`

### 3. `build:cli` -- Компиляция CLI

```bash
bun build --compile src/cli.ts --outfile bin/sp-annotator
```

- Компилирует TypeScript CLI в standalone Bun binary
- HTML-файлы встраиваются через `import ... with { type: "text" }` (Bun import attribute)
- Результат: `bin/sp-annotator` (исполняемый файл)

## Порядок сборки

Порядок критически важен:

```
build:review  →  build:plan  →  build:cli
     │                │              │
     │                ├── использует review.html из build:review
     │                │
     └── dist/index.html ─── копируется → dist/review.html
                                              │
                     dist/index.html ─────────┤
                                              │
                                     cli.ts импортирует оба HTML
                                              │
                                     bin/sp-annotator (binary)
```

## Dev-серверы

Для разработки UI без пересборки CLI:

### Plan Editor (annotate/review UI)

```bash
bun run dev:plan
```

- Запускает Vite dev server на `http://localhost:3000`
- Hot reload
- Требует отдельно запущенный backend (annotate server)

### Review App (diff UI)

```bash
bun run dev:review
```

- Запускает Vite dev server на `http://localhost:3001`
- Hot reload
- Требует отдельно запущенный backend (review server)

## Vite-конфигурация

Обе Vite-конфигурации (`apps/plan-editor/vite.config.ts`, `apps/review-app/vite.config.ts`) используют:

- `@vitejs/plugin-react` -- JSX transform
- `@tailwindcss/vite` -- Tailwind CSS 4
- `vite-plugin-singlefile` -- инлайн всех JS/CSS/ассетов в один HTML
- `target: "esnext"` -- современный JavaScript
- `assetsInlineLimit: 100000000` -- инлайн всех ассетов
- `inlineDynamicImports: true` -- один bundle

## Compiled Output

Результат полной сборки -- один исполняемый файл:

```
bin/sp-annotator
```

Использование:

```bash
# Аннотирование markdown-файла
./bin/sp-annotator annotate path/to/file.md

# Ревью markdown-файла
./bin/sp-annotator review path/to/file.md

# Code review локального diff
./bin/sp-annotator diff

# Code review PR
./bin/sp-annotator diff https://github.com/owner/repo/pull/123
```

Глобальные флаги:

```bash
--browser <name>    # Переопределить браузер (напр. --browser firefox)
```

## Переменные окружения

| Переменная            | Описание                                             | По умолчанию                   |
| --------------------- | ---------------------------------------------------- | ------------------------------ |
| `PLANNOTATOR_REMOTE`  | `1` или `true` для remote-режима (SSH, devcontainer) | не установлена                 |
| `PLANNOTATOR_PORT`    | Фиксированный порт сервера                           | random (local), 19432 (remote) |
| `PLANNOTATOR_BROWSER` | Браузер для открытия UI                              | системный по умолчанию         |
