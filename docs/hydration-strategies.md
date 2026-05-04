---
title: Hydration Strategies
description: A guide to Coldspa's hydration strategies.
---

`strategy=` on `<cf_Island>` controls **when** (and **whether**) the component is rendered.

| Strategy  | SSR'd HTML? | Client boots when…                                       |
|-----------|-------------|----------------------------------------------------------|
| `load`    | yes         | the module loads (default)                               |
| `idle`    | yes         | `requestIdleCallback` fires                              |
| `visible` | yes         | the mount enters the viewport (`IntersectionObserver`)   |
| `client`  | **no**      | the module loads (no SSR HTML or CSS is emitted)         |

## When to use each

- **`load`** — small, above-the-fold widgets that need to be interactive immediately.
- **`idle`** — non-critical interactivity (analytics opt-ins, comment widgets) that should wait for the main thread to free up.
- **`visible`** — long pages where most islands are below the fold. Avoids paying hydration cost for things the user may never scroll to.
- **`client`** — components that depend on browser-only APIs (`window`, IndexedDB, `MediaDevices`, etc.) or where SSR isn't worth the round-trip.

## How it works

Each strategy compiles to a different boot wrapper around the framework's `mount()` call:

- `load` / `client`: bare `<script type="module">` that mounts immediately.
- `idle`: wrapped in `requestIdleCallback` (with a `setTimeout(200)` fallback).
- `visible`: wrapped in an `IntersectionObserver` on the mount element. Observer disconnects after the first intersection.

For `client`, Coldspa skips the SSR sidecar call entirely — no HTML, no CSS pre-render — and the framework client uses `createApp` (Vue) or `createRoot` (React) instead of the hydration variant.
