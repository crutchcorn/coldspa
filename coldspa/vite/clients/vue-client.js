// Coldspa Vue client entry. Bundled by Vite via the coldspa plugin.
// __COLDSPA_GLOB__ is replaced at build time by the plugin's transform hook.
//
// `options.strategy === 'client'` -> createApp    (fresh client render)
// otherwise                        -> createSSRApp (hydrates SSR markup)
//
// `options.hasSlot` + `options.slotId` -> read raw HTML from a sibling
// <template id="slotId"> and inject it as the component's default slot via
// createStaticVNode. The same path runs server-side (vue-ssr.js) so SSR
// markup matches the client render byte-for-byte.
import { createApp, createSSRApp, h, createStaticVNode } from 'vue';

const components = import.meta.glob('__COLDSPA_GLOB__');

export async function mount(componentPath, el, props, options) {
    if (!el) return;
    const loader = components[componentPath];
    if (!loader) {
        console.error(
            `[Coldspa] No Vue component registered for path "${componentPath}". ` +
            `Make sure it matches the glob configured in the coldspa Vite plugin.`
        );
        return;
    }
    const mod = await loader();

    const slots = {};
    if (options && options.hasSlot && options.slotId) {
        const tpl = document.getElementById(options.slotId);
        const slotHtml = tpl ? tpl.innerHTML : '';
        if (slotHtml) {
            slots.default = () => createStaticVNode(slotHtml, 1);
        }
    }
    if (options && options.namedSlotIds) {
        for (const [name, id] of Object.entries(options.namedSlotIds)) {
            const tpl = document.getElementById(id);
            const html = tpl ? tpl.innerHTML : '';
            if (html) slots[name] = () => createStaticVNode(html, 1);
        }
    }

    const factory = options && options.strategy === 'client' ? createApp : createSSRApp;
    factory({
        render: () => h(mod.default, props, slots)
    }).mount(el);
}
