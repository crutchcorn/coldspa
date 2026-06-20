---
title: Getting Started
description: A step-by-step guide to setting up Coldspa in a new project.
---

This walks through wiring Coldspa into a fresh project from scratch — installing both halves (CFML + Node), setting up the renderer, and rendering your first island.

## Prerequisites

- ColdFusion (Adobe ColdFusion 2023+ or Lucee 5+)
- Node.js 22+
- A web server pointed at your CFML webroot
- One of: Vue 3 / React 18+

## 1. Install the CFML side

Via [CommandBox](https://www.ortussolutions.com/products/commandbox):

```bash
box install coldspa
```

This drops the package at `./modules/coldspa/`, including `Island.cfm`, `Slot.cfm`, the renderer files (`coldspa/renderers/Vue.cfm`, `coldspa/renderers/React.cfm`), and the SSR sidecar.

## 2. Wire up `Application.cfc`

Two things need to happen here:

1. Register the module's directory as a custom tag path so `<cf_Island>` and `<cf_Slot>` resolve from anywhere.
2. Delegate the three lifecycle methods to `coldspa.Bootstrap` so Coldspa can cache its config and auto-spawn the Vite dev server + Node SSR sidecar.

```cfc
// Application.cfc
component {
    this.name = "MyApp";
    this.customTagPaths = expandPath("/modules/coldspa");

    function onApplicationStart() {
        new coldspa.Bootstrap().onApplicationStart();
        return true;
    }

    function onApplicationStop() {
        new coldspa.Bootstrap().onApplicationStop();
    }

    function onRequestStart(targetPage) {
        new coldspa.Bootstrap().onRequestStart();
        return true;
    }
}
```

What each delegate does:

- `onApplicationStart` — caches `application.coldspaConfig` and (in dev) spawns `vite` and the SSR sidecar in the background. In production it validates `dist/.vite/manifest.json` and runs `npm run build` once if it's missing.
- `onApplicationStop` — tears down the spawned Node processes so they don't outlive the CF app.
- `onRequestStart` — enables the `?reloadConfig=1` and `?reloadApp=1` dev hooks. No-op otherwise.

Logs from the spawned processes land in `WEB-INF/coldspa-logs/{vite,ssr,manager}.log`.

**ColdBox users can skip this step entirely** — the bundled `ModuleConfig.cfc` registers the custom tag path *and* hooks `Bootstrap` into the `afterAspectsLoad`, `preReinit`, and `preProcess` interceptors.

**Managing Node yourself?** If you'd rather run Vite/SSR under systemd, docker-compose, or your platform's process supervisor, set `COLDSPA_NO_BOOTSTRAP=1` in the CF process env. `Bootstrap.onApplicationStart` will still cache config but skip the spawn. Coldspa also auto-detects this when `npm` isn't on PATH (the typical CF-in-Docker case) — see [Docker & cross-host setups](docker).

## 3. Install the Node side

Coldspa uses Vite for asset bundling and a small Node sidecar for server-side rendering.

```bash
npm install coldspa vite vue @vitejs/plugin-vue           # Vue
# or
npm install coldspa vite react react-dom @vitejs/plugin-react   # React
```

Coldspa lists every runtime framework package as an **optional peer dependency**, so you only install what you actually use. Install the matching Vite framework plugin in your app because your Vite config owns that setup.

## 4. Configure Vite

```js
// vite.config.js
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import coldspa from 'coldspa/vite';

export default defineConfig({
    plugins: [
        vue(),
        coldspa({
            frameworks: ['vue'],
            globs: {
                vue: '/src/**/*.vue'
            }
        })
    ]
});
```

For React, import `react` from `@vitejs/plugin-react`, add `react()` to `plugins`, and set `frameworks: ['react']`. For mixed Vue + React configs, include both framework plugins before `coldspa(...)`.

The Coldspa plugin handles client-entry shims, manifest output, and dev-server host binding for you.

## 5. Add `package.json` scripts

```json
{
    "scripts": {
        "dev":      "vite",
        "ssr":      "node node_modules/coldspa/coldspa/vite/ssr-server.js",
        "build":    "vite build && cross-env COLDSPA_SSR=1 vite build",
        "ssr:prod": "cross-env NODE_ENV=production node node_modules/coldspa/coldspa/vite/ssr-server.js"
    }
}
```

The `ssr` script can also be invoked via the `coldspa-ssr` bin shipped in the npm package.

## 6. Configure runtime URLs (optional)

For local single-host dev, the defaults are fine. Otherwise create a `coldspa.config.json` at the webroot:

```json
{
    "isDev":   true,
    "ssrUrl":  "http://127.0.0.1:5174",
    "viteUrl": "http://localhost:5173"
}
```

See [Configuration](configuration) for every key and [Docker & cross-host setups](docker) when CF and Node live on different machines or containers.

## 7. Write your first component

```vue
<!-- src/App.vue -->
<script setup>
defineProps({ hello: { type: String, default: '' } });
</script>

<template>
    <div class="island">
        <h2>Hello, {{ hello }}!</h2>
        <slot />
    </div>
</template>
```

## 8. Mount it from CFML

```cfml
<!--- index.cfm --->
<cfinclude template="/modules/coldspa/coldspa/renderers/Vue.cfm">

<cf_Island
    framework="#Vue#"
    path="./src/App.vue"
    props="#{ hello: 'World' }#"
    strategy="visible">

    <p>This sentence comes from the default slot in CFML.</p>
</cf_Island>
```

## 9. Run it

Start your CF server. That's it — `Bootstrap.onApplicationStart` spawns both `vite` and the SSR sidecar for you in the background. Load the page and you should see your component server-rendered into the response, then hydrated when it scrolls into view.

If you'd rather drive the Node side yourself (set `COLDSPA_NO_BOOTSTRAP=1` first), use two terminals:

```bash
npm run dev      # Vite dev server (HMR)
npm run ssr      # Node SSR sidecar
```

During iteration:

- `?reloadConfig=1` — re-reads `coldspa.config.json` + env vars without bouncing the app.
- `?reloadApp=1` — also tears down and re-spawns the Node processes.

## 10. Build for production

```bash
npm run build      # builds client bundle (dist/) AND SSR bundle (dist-ssr/)
npm run ssr:prod   # runs the sidecar against the built bundle
```

Set `isDev: false` (or `CF_ENV=production`) so CFML reads from `dist/.vite/manifest.json` instead of the dev server. With `Bootstrap` wired up, the production sidecar (`npm run ssr:prod` equivalent) is launched automatically on `onApplicationStart` — no separate process to babysit. Set `COLDSPA_NO_BOOTSTRAP=1` if you'd rather run it under systemd / docker-compose / your platform's supervisor.

## Where to next

- [Hydration strategies](hydration-strategies) — `load`, `idle`, `visible`, `client`
- [Slots](slots) — default + named slots, `<cf_Slot>` rules, gotchas
- [Configuration](configuration) — full env var and `coldspa.config.json` reference
- [Docker & cross-host setups](docker) — CF and Vite on different hosts
