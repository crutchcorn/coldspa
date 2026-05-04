// Coldspa Vue client entry.
// This file is served by Vite (dev) or bundled by Vite (prod), so the
// bare `vue` specifier gets resolved by Vite, not the browser.
import { createApp } from 'vue';

export function mount(Component, el, props) {
    if (!el) return;
    createApp(Component, props).mount(el);
}
