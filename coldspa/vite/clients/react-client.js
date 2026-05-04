// Coldspa React client entry. Bundled by Vite via the coldspa plugin.
// __COLDSPA_GLOB__ is replaced at build time by the plugin's transform hook.
//
// `options.strategy === 'client'` -> createRoot   (fresh client render)
// otherwise                        -> hydrateRoot (hydrates SSR markup)
import React from 'react';
import { createRoot, hydrateRoot } from 'react-dom/client';

const components = import.meta.glob('__COLDSPA_GLOB__');

export async function mount(componentPath, el, props, options) {
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
    const node = React.createElement(mod.default, props);
    if (options && options.strategy === 'client') {
        createRoot(el).render(node);
    } else {
        hydrateRoot(el, node);
    }
}
