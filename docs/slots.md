# Slots

`cf_Island` captures any HTML between its opening and closing tags and passes it to your component as the default slot. You can render dynamic CFML markup (queries, conditionals, includes) and project it straight into a Vue/React component.

## Usage

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

## How it works

1. `cf_Island` runs on the **end** pass and reads the rendered body from `thisTag.generatedContent` as raw HTML.
2. The HTML is stashed in a sibling `<template id="slot-<uid>">` element (inert, scripts inside don't execute).
3. The mount options passed to the client include `{ slotId, hasSlot }`.
4. On both server (SSR sidecar) and client, the slot HTML is injected via Vue's `createStaticVNode` (or React's `dangerouslySetInnerHTML`) so SSR markup and hydration match byte-for-byte.

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
