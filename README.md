<div align="center">
<h1>Coldspa</h1>

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/crutchcorn/tempblot/refs/heads/main/website/public/coldspa_dark.png">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/crutchcorn/tempblot/refs/heads/main/website/public/coldspa_light.png">
    <img height="80" width="80" alt="splatter" src="https://raw.githubusercontent.com/crutchcorn/tempblot/refs/heads/main/website/public/favicon.svg">
</picture>

<p>Give your CFML a spa day. The Islands Architecture for ColdFusion.</p>

</div>

<hr />

[![Build Status](https://img.shields.io/github/actions/workflow/status/crutchcorn/coldspa/ci.yml?branch=main&style=flat-square&label=Tests)](https://github.com/crutchcorn/coldspa/actions/workflows/ci.yml?query=branch%3Amain)
[![ForgeBox](https://img.shields.io/badge/ForgeBox-coldspa-2D3D55?style=flat-square&logoColor=white)](https://www.forgebox.io/view/coldspa)
[![NPM Version](https://img.shields.io/npm/v/coldspa?style=flat-square&label=NPM)](https://www.npmjs.com/package/coldspa)
[![NPM downloads](https://img.shields.io/npm/dw/coldspa?style=flat-square&label=NPM%20Downloads)](https://www.npmjs.com/package/coldspa)
[![MIT License](https://img.shields.io/npm/l/coldspa?style=flat-square&label=License)](./LICENSE)

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

That's it — start your CF server and load the page. `coldspa.Bootstrap` auto-spawns the Vite dev server and Node SSR sidecar in the background and tears them down on app stop. For Docker, supervised deployments, or opting out, see [Getting started](docs/getting-started.md).

## Documentation

- [Getting started](docs/getting-started.md) — full setup walkthrough
- [Hydration strategies](docs/hydration-strategies.md) — `load`, `idle`, `visible`, `client`
- [Slots](docs/slots.md) — default + named slots, `cf_Slot`, gotchas
- [Configuration](docs/configuration.md) — `coldspa.config.json`, env vars
- [Docker & cross-host setups](docs/docker.md) — running CF and Vite on different hosts

