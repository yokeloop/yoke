---
name: dev-workflow
description: Running the PokerNode dev environment with just
user-invocable: true
---

# Dev Workflow

## Starting the full dev environment

```bash
just dev
```

This single command:

1. Ensures MongoDB (port 27017) and Redis (port 6379) Docker containers are running
2. Starts the Game Engine binary (`assets/poker-server-0.3.4`), waits for health check
3. Launches Fastify API (port 3000) and Vite frontend (port 5173) via `concurrently`

Output is color-coded: `[engine]` red, `[api]` blue, `[app]` green. Press `Ctrl+C` to stop all.

## Individual services

```bash
just engine    # Game Engine only (Rust binary, ports 8080/8081/50051)
just api       # Fastify API only (cd api && pnpm dev, port 3000)
just app       # Frontend Vite only (pnpm dev, port 5173)
```

## Infrastructure

```bash
just db        # Ensure Mongo + Redis Docker containers running
just health    # Health check all services
just stop      # Stop Docker containers
just install   # Install pnpm deps (frontend + API)
```

## Configuration

Engine binary and flags are set in `Justfile` variables at the top:

```just
engine_bin := "assets/poker-server-0.3.4"
engine_flags := ""
```

Update `engine_bin` when a new server binary is added.

## Required before first run

1. Install `just`: `sudo pacman -S just` (Arch) or `brew install just` (macOS)
2. Docker running (for MongoDB and Redis containers)
3. `api/.env` file configured (see README.md for template)
4. `just install` to install dependencies

## Health checks

```bash
curl http://localhost:8080/health   # Game Engine
curl http://localhost:3000/health   # Fastify API
```

## Ports reference

| Service          | Port  |
| ---------------- | ----- |
| Frontend (Vite)  | 5173  |
| Fastify API      | 3000  |
| MongoDB          | 27017 |
| Redis            | 6379  |
| Game Engine HTTP | 8080  |
| Game Engine WS   | 8081  |
| Game Engine gRPC | 50051 |
