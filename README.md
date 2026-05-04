# Coldspa

Astro-style framework islands for ColdFusion. Mount Vue (and React, soon) components into CFML pages with server-side rendering and progressive hydration.

```cfml
<cfinclude template="/coldspa/renderers/Vue.cfm">

<cf_Island
    framework="#Vue#"
    path="./src/App.vue"
    props="#{ hello: 'World' }#"
    strategy="visible">
</cf_Island>
```

## Quick start

```bash
npm install
npm run dev      # Vite dev server (HMR)
npm run ssr      # Node SSR sidecar
```

For production:

```bash
npm run build      # builds client + SSR bundles
npm run ssr:prod   # runs the sidecar against the built bundle
```

## Configuration

Coldspa resolves config in this order (highest priority first):

1. **Environment variables** — for CI/CD, Docker, prod
2. **`island-config.json`** in the webroot — for local dev / Admin UI
3. **Built-in defaults**

### Environment variables

| Variable            | Effect                                                                   |
|---------------------|--------------------------------------------------------------------------|
| `CF_ENV`            | `development` / `dev` switches Coldspa to dev mode                       |
| `COLDSPA_SSR_URL`   | Where **CF** reaches the SSR sidecar (server-to-server)                  |
| `COLDSPA_VITE_URL`  | Where the **browser** reaches the Vite dev server (used for asset URLs)  |
| `COLDSPA_SSR_PORT`  | (sidecar) Port to listen on. Default `5174`                              |
| `COLDSPA_SSR_HOST`  | (sidecar) Bind address. Default `0.0.0.0`. Use `127.0.0.1` to lock down  |
| `NODE_ENV`          | (sidecar) `production` switches sidecar to use built bundle              |

### `island-config.json`

Lives in the webroot. Should be `.gitignore`d (it can be edited via the CF Admin UI). Any keys you set here are merged on top of defaults but overridden by env vars.

```json
{
    "isDev": true,
    "ssrUrl":  "http://127.0.0.1:5174",
    "viteUrl": "http://localhost:5173",
    "vitePort": "5173"
}
```

| Key        | Default                  | Description                                                 |
|------------|--------------------------|-------------------------------------------------------------|
| `isDev`    | `false`                  | Dev mode (uses Vite dev server) vs prod (uses `dist/`)      |
| `ssrUrl`   | `http://127.0.0.1:5174`  | SSR sidecar URL (server-to-server)                          |
| `viteUrl`  | unset                    | Browser-facing Vite URL. Falls back to `localhost:vitePort` |
| `vitePort` | `"5173"`                 | Used to build the default `viteUrl` if `viteUrl` is unset   |

After editing `island-config.json`, request any page with `?reloadApp=1` to bust the cached config (or restart CF).

### Docker / cross-host setups

Two URLs need to work from **different perspectives**:

- `ssrUrl` — CF → Node sidecar (server-to-server). Set this on the CF container.
- `viteUrl` — Browser → Vite dev server. Set this so generated `<script src="...">` URLs are reachable from the user's browser.

Common patterns:

| Setup                                        | `ssrUrl`                            | `viteUrl`                          |
|----------------------------------------------|-------------------------------------|------------------------------------|
| All on one host                              | `http://127.0.0.1:5174`             | _(unset — defaults to localhost)_  |
| CF in Docker, Node on host (Win/Mac)         | `http://host.docker.internal:5174`  | `http://host.docker.internal:5173` |
| CF in Docker, Node on host (Linux)           | `http://host.docker.internal:5174` ¹ | `http://host.docker.internal:5173` ¹ |
| Both in docker-compose (sidecar service `coldspa-ssr`) | `http://coldspa-ssr:5174` | `http://localhost:5173` ²          |

¹ On Linux, add `--add-host=host.docker.internal:host-gateway` to the CF container.
² The browser still hits `localhost` because Vite's port is published from the compose stack to the host.

### Vite dev server host binding

When `viteUrl` (or `COLDSPA_VITE_URL`) points at a non-localhost host, the Coldspa Vite plugin automatically:

- binds the dev server to all interfaces (`server.host: true`)
- adds the discovered hostname to `server.allowedHosts` so Vite 5.4+ doesn't reject the request with `403 Forbidden`
- sets `server.origin` and `server.hmr.host` so generated asset / HMR URLs use the external hostname

No extra Vite config is required — just set the URL.
