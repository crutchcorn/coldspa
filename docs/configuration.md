---
title: Configuration
description: Configure Coldspa's behavior via `coldspa.config.json` or environment variables.
---

Coldspa resolves config in this order (highest priority first):

1. **Environment variables** — for CI/CD, Docker, prod
2. **`coldspa.config.json`** in the webroot — for local dev / Admin UI
3. **Built-in defaults**

## Environment variables

| Variable            | Effect                                                                   |
|---------------------|--------------------------------------------------------------------------|
| `CF_ENV`            | `development` / `dev` switches Coldspa to dev mode                       |
| `COLDSPA_SSR_URL`   | Where **CF** reaches the SSR sidecar (server-to-server)                  |
| `COLDSPA_VITE_URL`  | Where the **browser** reaches the Vite dev server (used for asset URLs)  |
| `COLDSPA_DEBUG`     | `1` / `true` emits diagnostic HTML comments per island                   |
| `COLDSPA_NO_BOOTSTRAP` | `1` / `true` disables the auto-spawn of Vite + SSR sidecar in `onApplicationStart`. Use when you manage Node processes yourself (systemd, docker-compose, etc.) |
| `COLDSPA_SSR_PORT`  | (sidecar) Port to listen on. Default `5174`                              |
| `COLDSPA_SSR_HOST`  | (sidecar) Bind address. Default `0.0.0.0`. Use `127.0.0.1` to lock down  |
| `NODE_ENV`          | (sidecar) `production` switches sidecar to use built bundle              |

## `coldspa.config.json`

Lives in the webroot. Should be `.gitignore`d (it can be edited via the CF Admin UI). Any keys you set here are merged on top of defaults but overridden by env vars.

```json
{
    "isDev": true,
    "debug": false,
    "ssrUrl":  "http://127.0.0.1:5174",
    "viteUrl": "http://localhost:5173",
    "vitePort": "5173"
}
```

| Key        | Default                  | Description                                                 |
|------------|--------------------------|-------------------------------------------------------------|
| `isDev`    | `false`                  | Dev mode (uses Vite dev server) vs prod (uses `dist/`)      |
| `debug`    | `false`                  | Emit `<!-- coldspa SSR: ... -->` diagnostic comments        |
| `ssrUrl`   | `http://127.0.0.1:5174`  | SSR sidecar URL (server-to-server)                          |
| `viteUrl`  | unset                    | Browser-facing Vite URL. Falls back to `localhost:vitePort` |
| `vitePort` | `"5173"`                 | Used to build the default `viteUrl` if `viteUrl` is unset   |

After editing `coldspa.config.json`, request any page with `?reloadApp=1` to bust the cached config (or restart CF).
