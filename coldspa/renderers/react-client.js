// Coldspa React client entry.
// Served/bundled by Vite so bare `react` and `react-dom/client` specifiers resolve.
import React from 'react';
import { createRoot } from 'react-dom/client';

export function mount(Component, el, props) {
    if (!el) return;
    createRoot(el).render(React.createElement(Component, props));
}
