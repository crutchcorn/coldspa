// Coldspa React client entry. Bundled by Vite via the coldspa plugin.
// __COLDSPA_GLOB__ is replaced at build time by the plugin's transform hook.
//
// `options.strategy === 'client'` -> createRoot   (fresh client render)
// otherwise                        -> hydrateRoot (hydrates SSR markup)
//
// `options.hasSlot` + `options.slotId` -> read raw HTML from <template id=...>
// and pass it as `children` via dangerouslySetInnerHTML so the component can
// render the CF-emitted slot HTML.
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

    let children;
    if (options && options.hasSlot && options.slotId) {
        const tpl = document.getElementById(options.slotId);
        const slotHtml = tpl ? tpl.innerHTML : '';
        if (slotHtml) {
            // Wrapper span so the component can decide where children go.
            children = React.createElement('span', {
                dangerouslySetInnerHTML: { __html: slotHtml }
            });
        }
    }

    const node = React.createElement(mod.default, props, children);
    if (options && options.strategy === 'client') {
        createRoot(el).render(node);
    } else {
        hydrateRoot(el, node);
    }
}
