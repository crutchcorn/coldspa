# Coldspa

Give your CFML a spa day. The Islands Architecture for ColdFusion. Mount Vue or React components into CFML pages with server-side rendering and progressive hydration.

## Install

```bash
npm install coldspa vite vue   # or: react react-dom
```

## Configure Vite

```js
// vite.config.js
import { defineConfig } from 'vite';
import coldspa from 'coldspa/vite';

export default defineConfig({
    plugins: [
        coldspa({
            frameworks: ['vue'],            // or ['vue', 'react']
            globs: { vue: '/src/**/*.vue' } // where your components live
        })
    ]
});
```

## Use it from CFML

```cfml
<cfinclude template="/coldspa/renderers/Vue.cfm">

<cf_Island
    framework="#Vue#"
    path="./src/App.vue"
    props="#{ hello: 'World' }#"
    strategy="visible">

    <p>Default-slot content rendered by CFML.</p>

    <cf_Slot name="header">
        <h2>Header from CFML</h2>
    </cf_Slot>
</cf_Island>
```

## Run it

```bash
npm run dev      # Vite dev server (HMR)
npm run ssr      # Node SSR sidecar
```

For production:

```bash
npm run build      # builds client + SSR bundles
npm run ssr:prod   # runs the sidecar against the built bundle
```

## Documentation

- [Hydration strategies](docs/hydration-strategies.md) — `load`, `idle`, `visible`, `client`
- [Slots](docs/slots.md) — default + named slots, `cf_Slot`, gotchas
- [Configuration](docs/configuration.md) — `coldspa.config.json`, env vars
- [Docker & cross-host setups](docs/docker.md) — running CF and Vite on different hosts

