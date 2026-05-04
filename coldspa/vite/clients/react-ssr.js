// Coldspa React SSR entry. Bundled by Vite with build.ssr=true via the coldspa plugin.
// __COLDSPA_GLOB__ is replaced at build time.
//
// Mirrors the client's slot semantics:
//   - Default slot HTML -> <span dangerouslySetInnerHTML> as `children`
//   - Each named slot   -> <span dangerouslySetInnerHTML> as a same-named prop
//
// Output uses renderToString (not renderToStaticMarkup) so React inserts the
// data-reactroot / hydration markers needed for hydrateRoot on the client.
import React from 'react';
import { renderToString } from 'react-dom/server';

const components = import.meta.glob('__COLDSPA_GLOB__');

export async function render(componentPath, props, slotHtml, namedSlots) {
    const loader = components[componentPath];
    if (!loader) {
        throw new Error(`[Coldspa SSR] No React component registered for path "${componentPath}".`);
    }
    const mod = await loader();

    let children;
    if (slotHtml) {
        children = React.createElement('span', {
            dangerouslySetInnerHTML: { __html: slotHtml }
        });
    }

    const slotProps = {};
    if (namedSlots) {
        for (const [name, html] of Object.entries(namedSlots)) {
            if (html) {
                slotProps[name] = React.createElement('span', {
                    dangerouslySetInnerHTML: { __html: html }
                });
            }
        }
    }

    const node = React.createElement(mod.default, { ...props, ...slotProps }, children);
    return renderToString(node);
}
