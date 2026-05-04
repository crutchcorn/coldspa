# ColdFusion Island Architecture — Design Decisions

## Overview

A ColdFusion library called Coldspa that brings Astro-style framework islands to ColdFusion
applications. Allows teams to incrementally adopt modern frontend frameworks
(Vue, React, Svelte, etc.) without rewriting existing CFM-based apps.

---

## Core Concept: `cf_Island`

Borrowing Astro's island architecture. Each island is a self-contained frontend
component mounted into a ColdFusion-rendered page. ColdFusion owns:

- Data fetching
- Auth/session
- Routing
- Props serialization

The JS framework owns:

- Interactivity
- Component rendering
- TypeScript/CSS

### Tag API

```cfml
<cfimport path="coldspa.renderers.Vue">

<cfscript>
props = {
    hello: "World"
};
</cfscript>

<cf_Island
    framework="#Vue#"
    path="./App.vue"
    props="#props#"
    strategy="visible">
</cf_Island>
```

### Attributes

| Attribute   | Type   | Default      | Description                          |
|-------------|--------|--------------|--------------------------------------|
| `framework` | struct | required     | Renderer struct (see Renderers)      |
| `path`      | string | required     | Path to component file               |
| `props`     | struct | `{}`         | Serialized as JSON into JS           |
| `strategy`  | string | `"load"`     | Hydration strategy                   |

---

## Renderer Pattern

Frameworks are passed as structs with a `render()` function. This keeps
`cf_Island` framework-agnostic.

### Interface

Each renderer is a CFC in `coldspa/renderers/` that assigns a struct to
`caller.<FrameworkName>` containing:

```
{
    name: string,
    render: function(mountId, resolvedPath, propsJson) => string
}
```

The `render()` function returns a JS string that imports and mounts the
component.

### Built-in Renderers

- `coldspa.renderers.Vue` — uses `createApp().mount()`
- `coldspa.renderers.React` — uses `createRoot().render()`

Additional renderers can be authored by library consumers following the same
interface.

---

## Hydration Strategies

Mirrors Astro's client directives:

| Strategy   | Behavior                                            |
|------------|-----------------------------------------------------|
| `load`     | Hydrates immediately on page load                   |
| `idle`     | Hydrates via `requestIdleCallback()`                |
| `visible`  | Hydrates via `IntersectionObserver` when in viewport|

---

## Configuration System (`IslandConfig.cfc`)

A singleton CFC that owns all config resolution with the following precedence:

```
CF_ENV environment variable   ← highest priority (CI/CD, Docker)
        ↓ fallback
/island-config.json           ← written by CF Admin UI toggle
        ↓ fallback
"production"                  ← safe default
```

### Config Shape

```json
{
    "isDev": false,
    "vitePort": "5173"
}
```

### Lifecycle

- Loaded once in `Application.cfc` `onApplicationStart()` into
  `application.islandConfig`
- Saving via the Admin UI busts `application.islandConfig` immediately so
  changes take effect without a server restart

### `island-config.json`

- Should be in `.gitignore` — not committed to source control
- Written by the CF Admin toggle, not by hand

---

## Vite Integration

### Path Resolution

`cf_Island` resolves component paths differently by mode:

- **Dev:** Prefixes with `http://localhost:{vitePort}` to hit the Vite dev
  server
- **Prod:** Looks up the path in `/dist/.vite/manifest.json` to get the
  content-hashed filename

Resolved via a `resolveAsset(path)` utility inside `cf_Island.cfm`, using
`application.islandConfig` to determine mode.

### Build Behavior

#### Development

On `onApplicationStart()`, spin up the Vite dev server as a sidecar process
via `cfexecute`. HMR and watch mode work as expected.

#### Production (Happy Path)

CI/CD is responsible for running `vite build` before deployment. The built
manifest at `/dist/.vite/manifest.json` is committed to the release artifact
(not to source control).

#### Production (Fallback)

On `onApplicationStart()`, if `isDev` is false and no manifest exists:

1. Log a **warning** to the `island-build` log file indicating the build is
   being run at startup (signals a broken deploy pipeline)
2. Run `vite build` via `cfexecute` with a timeout
3. If the build fails, throw an exception — do not silently serve a broken app

This "emergency build" prevents a completely broken first boot without fighting
against CI/CD as the happy path.

### README Framing

| Environment | Expected Behavior                                          |
|-------------|-------------------------------------------------------------|
| Development | Vite dev server starts automatically with CF               |
| Production  | CI/CD runs `vite build`. CF validates manifest on start.   |

Node.js must be installed on any server where automatic builds may run
(development always, production only as fallback).

---

## Sharp Edges / Known Limitations

### Props Type Safety

Props are passed as a CF struct → serialized to JSON → received as Vue/React
props. There is no compile-time contract across that boundary. Consumers are
responsible for ensuring prop shapes match component definitions.

Future consideration: auto-generating `.d.ts` from CF struct definitions.

### Multiple Islands Per Page

Each `cf_Island` call generates a unique mount ID via `createUUID()`. Multiple
islands on the same page are fully supported.

### Node Dependency

`cfexecute` shells out to `node`. Node.js must be available in the PATH of
whatever user the CF server process runs as.
