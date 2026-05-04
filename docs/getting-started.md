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

## 2. Register the custom tag path

Add the module's directory to your app's custom tag paths so `<cf_Island>` and `<cf_Slot>` resolve from anywhere:

```cfc
// Application.cfc
component {
    this.name = "MyApp";
    this.customTagPaths = expandPath("/modules/coldspa");
}
```

ColdBox users can skip this step — the bundled `ModuleConfig.cfc` wires it automatically.

## 3. Install the Node side

Coldspa uses Vite for asset bundling and a small Node sidecar for server-side rendering.

```bash
npm install coldspa vite vue           # Vue
# or
npm install coldspa vite react react-dom @vitejs/plugin-react   # React
```

Coldspa lists every framework package as an **optional peer dependency**, so you only install what you actually use.

## 4. Configure Vite

```js
// vite.config.js
import { defineConfig } from 'vite';
import coldspa from 'coldspa/vite';

export default defineConfig({
    plugins: [
        coldspa({
            frameworks: ['vue'],            // or ['vue', 'react']
            globs: {
                vue:   '/src/**/*.vue',
                react: '/src/**/*.{jsx,tsx}'
            }
        })
    ]
});
```

The plugin handles framework sub-plugins, client-entry shims, manifest output, and dev-server host binding for you.

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

In two terminals:

```bash
npm run dev      # Vite dev server (HMR)
npm run ssr      # Node SSR sidecar
```

Load the page. You should see your component server-rendered into the response, then hydrated when it scrolls into view.

## 10. Build for production

```bash
npm run build      # builds client bundle (dist/) AND SSR bundle (dist-ssr/)
npm run ssr:prod   # runs the sidecar against the built bundle
```

Set `isDev: false` (or unset `CF_ENV`) so CFML reads from `dist/.vite/manifest.json` instead of the dev server.

## Where to next

- [Hydration strategies](hydration-strategies) — `load`, `idle`, `visible`, `client`
- [Slots](slots) — default + named slots, `<cf_Slot>` rules, gotchas
- [Configuration](configuration) — full env var and `coldspa.config.json` reference
- [Docker & cross-host setups](docker) — CF and Vite on different hosts
