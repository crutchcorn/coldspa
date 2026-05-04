---
title: Docker & cross-host setups
description: How to configure Coldspa when CF and the Vite/Node sidecar run on different hosts (e.g. CF in Docker, Vite/Node on the host).
---

When CF and the Vite/Node sidecar live on different hosts (most commonly: CF in a Docker container, Vite/Node on the host), two URLs need to work from **different perspectives**:

- `ssrUrl` — CF → Node sidecar (server-to-server). Set this on the CF container.
- `viteUrl` — Browser → Vite dev server. Set this so generated `<script src="...">` URLs are reachable from the user's browser.

## Common patterns

| Setup                                        | `ssrUrl`                            | `viteUrl`                          |
|----------------------------------------------|-------------------------------------|------------------------------------|
| All on one host                              | `http://127.0.0.1:5174`             | _(unset — defaults to localhost)_  |
| CF in Docker, Node on host (Win/Mac)         | `http://host.docker.internal:5174`  | `http://host.docker.internal:5173` |
| CF in Docker, Node on host (Linux)           | `http://host.docker.internal:5174` ¹ | `http://host.docker.internal:5173` ¹ |
| Both in docker-compose (sidecar service `coldspa-ssr`) | `http://coldspa-ssr:5174` | `http://localhost:5173` ²          |

¹ On Linux, add `--add-host=host.docker.internal:host-gateway` to the CF container.
² The browser still hits `localhost` because Vite's port is published from the compose stack to the host.

## Vite dev server host binding

When `viteUrl` (or `COLDSPA_VITE_URL`) points at a non-localhost host, the Coldspa Vite plugin automatically:

- binds the dev server to all interfaces (`server.host: true`)
- adds the discovered hostname to `server.allowedHosts` so Vite 5.4+ doesn't reject the request with `403 Forbidden`
- sets `server.origin` and `server.hmr.host` so generated asset / HMR URLs use the external hostname

No extra Vite config is required — just set the URL.
