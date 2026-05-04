// Coldspa Vue SSR entry. Bundled by Vite with build.ssr=true via the coldspa plugin.
// __COLDSPA_GLOB__ is replaced at build time.
import { createSSRApp, h, createStaticVNode } from 'vue';
import { renderToString } from 'vue/server-renderer';

const components = import.meta.glob('__COLDSPA_GLOB__');

export async function render(componentPath, props, slotHtml, namedSlots) {
    const loader = components[componentPath];
    if (!loader) {
        throw new Error(`[Coldspa SSR] No Vue component registered for path "${componentPath}".`);
    }
    const mod = await loader();

    const slots = {};
    if (slotHtml) {
        slots.default = () => createStaticVNode(slotHtml, 1);
    }
    if (namedSlots) {
        for (const [name, html] of Object.entries(namedSlots)) {
            if (html) slots[name] = () => createStaticVNode(html, 1);
        }
    }

    const app = createSSRApp({
        render: () => h(mod.default, props, slots)
    });
    return await renderToString(app);
}
