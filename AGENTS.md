# AGENTS.md

Orientation for AI coding agents (and humans) working on Coldspa.

## What this project is

Coldspa is **the Islands Architecture for ColdFusion** — Astro-style islands that let CFML pages mount Vue or React components with server-side rendering and progressive hydration.

It is shipped as **two halves of one package**:

- **CFML half** (ForgeBox / `box install coldspa`) — custom tags (`<cf_Island>`, `<cf_Slot>`), framework renderers, lifecycle helper, process supervisor, and (for ColdBox) a `ModuleConfig.cfc`.
- **Node half** (npm / `npm install coldspa`) — a Vite plugin and a tiny HTTP SSR sidecar.

The two halves talk to each other over HTTP: CFML POSTs `{ componentPath, props, slotHtml, namedSlots }` at the sidecar, which calls the framework's `renderToString` and returns `{ imports, body }`. CFML stitches that into the response and emits a small mount script that hydrates on the configured strategy (`load`, `idle`, `visible`, `client`).

## Repo layout

This repo is **both the library source and a local development harness**. Be careful not to confuse the two:

```
/                                     <- webroot of a real CF app used for dev
├── coldspa/                          <- THE LIBRARY. This is what gets published.
│   ├── Bootstrap.cfc                   lifecycle helper consumers delegate to
│   ├── ColdspaConfig.cfc               singleton config (defaults + json + env)
│   ├── ProcessManager.cfc              spawns/tears-down vite + sidecar
│   ├── renderers/{Vue,React}.cfm       framework renderers (HTTP -> sidecar)
│   └── vite/
│       ├── plugin.js                   the published Vite plugin
│       ├── ssr-server.js               the published Node SSR sidecar
│       └── clients/                    {vue,react}-{client,ssr}.js entries
├── Island.cfm, Slot.cfm              <- THE LIBRARY (custom tags, top-level by design)
├── ModuleConfig.cfc                  <- THE LIBRARY (ColdBox auto-wire)
├── box.json, package.json            <- LIBRARY manifests (both halves)
├── README.md, LICENSE, docs/         <- LIBRARY docs
├── media/                            <- LIBRARY assets (logo)
│
├── Application.cfc                   <- DEV HARNESS ONLY. Not shipped.
├── index.cfm                         <- DEV HARNESS landing page. Not shipped.
├── vite.config.js                    <- DEV HARNESS. Not shipped.
├── vite.config.{vue,react}.js        <- DEV HARNESS. Not shipped.
├── coldspa.config.json               <- DEV HARNESS config. Not shipped.
├── crossdomain.xml, cfproject.md     <- DEV HARNESS / scaffolding.
├── demos/{vue,react}/                <- DEV HARNESS demos. Not shipped.
├── src/                              <- DEV HARNESS scratch space.
├── dist/, dist-ssr/                  <- BUILD OUTPUT of the dev harness.
├── WEB-INF/                          <- ColdFusion server runtime.
├── node_modules/                     <- npm install of the dev harness.
└── website/                          <- DOCS SITE (Astro Starlight, separate app).
```

### What gets published

- **ForgeBox / `box install coldspa`** — see `box.json`'s `ignore` list. It strips the dev-harness root files (`Application.cfc`, `index.cfm`, `vite.config*.js`, `demos/`, `src/`, `dist*/`, `node_modules/`, `WEB-INF/`, `website/`, etc.) and ships only `coldspa/`, `Island.cfm`, `Slot.cfm`, `ModuleConfig.cfc`, `box.json`, `README.md`, `LICENSE`.
- **npm / `npm install coldspa`** — see `package.json`'s `files` array and `exports` map. Self-references via `import coldspa from 'coldspa/vite'` work because of the `exports` map.

**Rule:** if you find yourself adding boilerplate to `Application.cfc` to make the demos work, that boilerplate **does not exist for consumers**. Either it belongs in `coldspa/Bootstrap.cfc` (so consumers can delegate to it), in `ModuleConfig.cfc` (so ColdBox consumers get it for free), or it doesn't belong at all.

### Why is `Island.cfm` at the webroot and not under `coldspa/`?

CF custom tag resolution. `<cf_Island>` requires a file literally named `Island.cfm` reachable through `this.customTagPaths`. We tell consumers to point `customTagPaths` at the module directory, so the tag files have to live at the top level of what the library ships — the publish layout flattens `coldspa/`-the-package such that `Island.cfm` and `coldspa/Bootstrap.cfc` end up siblings under `modules/coldspa/`.

## Architecture in one diagram

```
          Browser
            │   (HTML + tiny mount script)
            │   then a fetch to /modules/coldspa-built/...js to hydrate
            ▼
   ┌──────────────────────────────────────┐
   │            CFML request              │
   │  index.cfm                            │
   │    └─ <cf_Island framework="Vue">     │
   │        ├─ collects default slot HTML  │
   │        ├─ collects <cf_Slot> children │
   │        ├─ renderers/Vue.cfm           │
   │        │     POST {component,         │
   │        │           props, slots} ─────┼─────► Node SSR sidecar
   │        │                              │       (vite/ssr-server.js)
   │        │  receives {imports, body} ◄──┼──────  renderToString()
   │        ├─ writes <ssr-html>           │
   │        └─ writes mount script         │
   └──────────────────────────────────────┘
                      ▲
                      │ Vite plugin (coldspa/vite/plugin.js)
                      │ owns: framework sub-plugins, client-entry shims,
                      │       manifest, allowed hosts, hmr.host
                      ▼
                Vite dev server (or built dist/)
```

`ProcessManager.cfc` spawns the Vite dev server and the SSR sidecar in the background from `Bootstrap.onApplicationStart()`, and tears them down on `onApplicationStop()`. In production it instead validates `dist/.vite/manifest.json`.

## Key design considerations

1. **Self-contained consumer experience.** A consumer should be able to: `box install coldspa` + `npm install coldspa vite vue` + paste a 5-line `Application.cfc` + paste a 5-line `vite.config.js` and have a working app. Don't add new required steps without updating both the [README](README.md) and [docs/getting-started.md](docs/getting-started.md).

2. **One bootstrap entry point.** All CFML-side side effects (config, process spawn, reload hooks) live in [coldspa/Bootstrap.cfc](coldspa/Bootstrap.cfc). `Application.cfc` (consumers') and `ModuleConfig.cfc` (ColdBox) should only *delegate* to it. Don't fork the logic.

3. **Optional peer deps.** Every framework package (`vue`, `react`, `react-dom`, `@vitejs/plugin-vue`, `@vitejs/plugin-react`) is declared as an *optional* peer dependency. The Vite plugin and SSR sidecar must `await import(...)` them lazily and only fail when the consumer actually opts into that framework.

4. **No Node inside the CF container.** Common Docker setup: CF in one container, Node in another (or on the host). `ProcessManager` probes for `npm` on PATH and silently skips spawning if it's missing, so `Bootstrap.onApplicationStart` is safe to call inside the CF container. The escape hatch for supervised setups is `COLDSPA_NO_BOOTSTRAP=1`. See [docs/docker.md](docs/docker.md).

5. **Background spawn, never block app start.** Spawning happens via `java.lang.ProcessBuilder` inside a `cfthread`, with stdin redirected to NUL/`/dev/null`. `cfexecute` is synchronous and would deadlock the application-scope lock — do not use it here.

6. **Dev/prod parity at the renderer boundary.** `renderers/{Vue,React}.cfm` produce the same `{imports, body}` shape regardless of mode. Dev imports point at the Vite dev server (with React Fast Refresh preamble injected for React); prod imports come from `dist/.vite/manifest.json`. Mount scripts are identical.

7. **Slots are HTML strings, not VNodes.** `<cf_Slot name="...">` children render to HTML inside CFML, then ride along in the SSR POST body and on the client mount payload. Vue uses `createStaticVNode(html, 1)` per slot; React wraps each in `<span dangerouslySetInnerHTML>`. The default slot maps to `children` (React) / unnamed `<slot/>` (Vue); named slots map by name.

8. **`coldspa.config.json` is optional.** Defaults work for single-host dev. Env vars (`CF_ENV`, `COLDSPA_SSR_URL`, `COLDSPA_VITE_URL`, `COLDSPA_DEBUG`, `COLDSPA_NO_BOOTSTRAP`) override the file. See [docs/configuration.md](docs/configuration.md).

## Running the dev harness

```bash
# CF: any local server pointing at this directory as webroot.
# Node: Bootstrap auto-spawns vite + sidecar on app start.
# Or run them yourself:
npm run dev               # vite (both frameworks via vite.config.js)
npm run vite:vue          # single-framework variant
npm run vite:react        # single-framework variant
npm run build             # builds both client + ssr bundles
```

Visit `/` for the landing page, `/demos/vue/` and `/demos/react/` for the framework demos. Use `?reloadConfig=1` to re-read config or `?reloadApp=1` to also re-spawn the Node processes.

Logs from the spawned processes go to `WEB-INF/coldspa-logs/{vite,ssr,manager}.log`.

## When making changes

- **Touching consumer-facing API?** Update [README.md](README.md), [docs/getting-started.md](docs/getting-started.md), and any other docs in [docs/](docs/) that reference the changed surface.
- **Touching `Bootstrap.cfc` / `ProcessManager.cfc` / `ModuleConfig.cfc`?** Verify both delegation paths still work: plain CFML (via `Application.cfc` calls) and ColdBox (via interceptors).
- **Touching the Vite plugin or SSR sidecar?** Run `npm run build` to confirm both Vue and React client + SSR bundles still produce.
- **Adding a new file?** Decide whether it's library or harness, and update `box.json`'s `ignore` list and/or `package.json`'s `files` array accordingly. When in doubt, the file is harness — keep the published surface small.
- **Don't `cfexecute` the Node side.** Use `ProcessManager` (which uses `ProcessBuilder` in a `cfthread`).
- **Don't add a hard dep on Vue or React.** They're optional peers — gate every framework-specific code path on the consumer's opt-in (`frameworks: [...]` in `vite.config.js`, framework arg on `<cf_Island>`).
