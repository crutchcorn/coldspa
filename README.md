<div align="center">
<h1>Coldspa</h1>

<a href="https://emojipedia.org/joypixels/2.0/bathtub">
  <img
    height="80"
    width="80"
    alt="bathtub"
    src="https://raw.githubusercontent.com/crutchcorn/coldspa/refs/heads/main/media/bathtub.png"
  />
</a>

<p>Give your CFML a spa day. The Islands Architecture for ColdFusion.</p>

</div>

<hr />

Mount Vue or React components into CFML pages with server-side rendering and progressive hydration.

## Install

CFML side (via [CommandBox](https://www.ortussolutions.com/products/commandbox) / ForgeBox):

```bash
box install coldspa
```

Node side (Vite plugin + SSR sidecar):

```bash
npm install coldspa vite vue   # or: react react-dom
```

## Setup

Register the module's directory as a custom tag path so `<cf_Island>` and `<cf_Slot>` resolve from anywhere in your app, and delegate to `coldspa.Bootstrap` from your lifecycle methods so Coldspa can boot the Vite + SSR sidecar processes:

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

ColdBox users can skip this — the bundled `ModuleConfig.cfc` registers the custom tag path and wires the bootstrap lifecycle automatically.

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

- [Getting started](docs/getting-started.md) — full setup walkthrough
- [Hydration strategies](docs/hydration-strategies.md) — `load`, `idle`, `visible`, `client`
- [Slots](docs/slots.md) — default + named slots, `cf_Slot`, gotchas
- [Configuration](docs/configuration.md) — `coldspa.config.json`, env vars
- [Docker & cross-host setups](docs/docker.md) — running CF and Vite on different hosts

