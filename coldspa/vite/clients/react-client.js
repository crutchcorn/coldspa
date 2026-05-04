// Coldspa React client entry. Bundled by Vite via the coldspa plugin.
import React from 'react';
import { createRoot } from 'react-dom/client';

const components = import.meta.glob('/src/**/*.{jsx,tsx}');

export async function mount(componentPath, el, props) {
    if (!el) return;
    const loader = components[componentPath];
    if (!loader) {
        console.error(
            `[Coldspa] No React component registered for path "${componentPath}". ` +
            `Make sure it matches the glob configured in the coldspa Vite plugin.`
        );
        return;
    }
    const mod = await loader();
    createRoot(el).render(React.createElement(mod.default, props));
}
