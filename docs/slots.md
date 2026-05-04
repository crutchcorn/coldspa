---
title: Slots
description: A guide to using slots in Coldspa components.
---

`cf_Island` captures any HTML between its opening and closing tags and passes it to your component as the **default** slot. Use the `<cf_Slot name="...">` child tag to project additional **named** slots. Both forms accept dynamic CFML markup (queries, conditionals, includes) and stream it straight into a Vue/React component.

## Default slot

### CFML side

```cfml
<cfquery name="userPosts" datasource="myDB">
    SELECT title, body, createdAt FROM posts
    WHERE userID = <cfqueryparam value="#session.userID#">
</cfquery>

<cf_Island framework="#Vue#" path="./src/PostList.vue" strategy="visible">
    <cfoutput query="userPosts">
        <article class="post">
            <h2>#title#</h2>
            <p>#body#</p>
            <time>#createdAt#</time>
        </article>
    </cfoutput>
</cf_Island>
```

### Vue component

```vue
<template>
    <div class="post-list">
        <slot />
    </div>
</template>
```

### React component

```jsx
export default function PostList({ children }) {
    return <div className="post-list">{children}</div>;
}
```

## Named slots

Wrap any sub-section of the body in `<cf_Slot name="...">` to expose it as a named slot. The wrapped HTML is **removed** from the default slot and routed to the framework as a named slot (Vue) or a same-named prop (React).

### CFML side

```cfml
<cf_Island framework="#Vue#" path="./src/Card.vue" strategy="visible">
    <p>This goes into the default slot.</p>

    <cf_Slot name="header">
        <h1>#post.title#</h1>
        <time>#dateFormat(post.createdAt, "yyyy-mm-dd")#</time>
    </cf_Slot>

    <cf_Slot name="footer">
        <cfoutput query="comments">
            <div class="comment">#author#: #body#</div>
        </cfoutput>
    </cf_Slot>
</cf_Island>
```

### Vue component

Named slots are exposed via `<slot name="...">`, exactly as Vue normally handles them:

```vue
<template>
    <article class="card">
        <header><slot name="header" /></header>
        <main><slot /></main>
        <footer><slot name="footer" /></footer>
    </article>
</template>
```

### React component

React doesn't have a slot concept, so each named slot is delivered as a **prop of the same name**, pre-wrapped in a `<span>` with the slot's HTML. The default slot is still `children`.

```jsx
export default function Card({ header, footer, children }) {
    return (
        <article className="card">
            <header>{header}</header>
            <main>{children}</main>
            <footer>{footer}</footer>
        </article>
    );
}
```

### Rules for `cf_Slot`

- **Must be nested directly inside a `cf_Island`.** Throws `Coldspa.OrphanSlot` otherwise.
- **`name` is required** and must be a valid identifier matching `^[A-Za-z_][A-Za-z0-9_]*$`. Throws `Coldspa.InvalidSlotName` otherwise.
- **`name="default"` is reserved.** Place default-slot content directly inside `cf_Island`.
- **Last write wins.** Two `<cf_Slot name="header">` tags in the same island? The second overwrites the first.
- The slot's own markup is stripped from the parent's `generatedContent`, so it never leaks into the default slot.

## How it works

1. `cf_Island` runs on **both passes**:
    - **Start pass**: initializes `namedSlots = {}` on the tag scope so child `<cf_Slot>` tags have somewhere to attach.
    - **End pass**: reads the rendered body from `thisTag.generatedContent` (default slot) plus the populated `namedSlots` struct.
2. Each `<cf_Slot>` runs on its end pass, walks up to the parent via `getBaseTagData("CF_ISLAND")`, and writes `parent.namedSlots[name] = body`.
3. Each slot's HTML (default + named) is stashed in a sibling `<template id="slot-<uid>[-<name>]">` element. `<template>` content is inert in the DOM, so scripts inside don't execute.
4. The mount options passed to the client include `{ slotId, hasSlot, namedSlotIds: { name: id, ... } }`.
5. On the SSR sidecar, the renderer assembles a slots object — `default` plus one entry per named slot — using Vue's `createStaticVNode`. The same payload (`{ slotHtml, namedSlots }`) is sent to `/render/<framework>` so SSR matches client byte-for-byte.
6. On the client:
    - **Vue** reads each `<template>` by id and builds the same slots object.
    - **React** reads each `<template>` and spreads named slots as props (`{...props, header: <span/>, footer: <span/>}`), with the default slot as `children`.

## Consequences and gotchas

These follow from running the tag on the end pass.

### Errors in the body abort the page

If a `<cfquery>` or expression inside the slot throws, the tag never gets to emit anything — the error propagates as it would in plain CFML. The island can't `try/catch` its own body.

### `cfabort` / `cfexit` in the body suppresses the island entirely

If the body short-circuits, no mount div, no `<template>`, no `<script>` — nothing gets emitted.

### The body always runs, even with no slot

Self-closing form (`<cf_Island ... />`) doesn't execute body code. But `<cf_Island ...></cf_Island>` does — even when empty. Don't put expensive queries in slots you don't actually project somewhere.

### No nested islands

Putting `<cf_Island>` inside another `<cf_Island>`'s body is currently **not supported**:

- The inner island's `<script type="module">` ends up serialized inside the outer's `<template>` element.
- `<template>` content is inert in the DOM, so the inner script never executes.
- The inner mount div renders, but never hydrates.

Keep islands sibling-level rather than nested.

### Slot HTML inherits CFML output rules

If you reference variables (`#name#`) inside the slot, you still need a surrounding `<cfoutput>` — same as any CFML body. JSX-style implicit interpolation does not happen.

### `<cfsetting enableCFOutputOnly="true">`

If a parent template has this set globally, body content that isn't inside an explicit `<cfoutput>` won't appear in the slot HTML. Wrap slot bodies in `<cfoutput>` when in doubt.

### Whitespace is preserved (mostly fine)

Outer whitespace is trimmed; interior whitespace from `<cfoutput query>` between tags is preserved. Vue's `createStaticVNode` skips diffing static blocks, so this won't cause hydration mismatches today — but if we ever switch slot rendering to a real template compile, this would need revisiting.

### No early-exit from the island itself

You can't decide *inside* the tag to skip rendering after seeing the body. Wrap the whole `<cf_Island>` in a `<cfif>` if you need conditional rendering.
