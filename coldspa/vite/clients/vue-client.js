// Coldspa Vue client entry. Bundled by Vite via the coldspa plugin.
// __COLDSPA_GLOB__ is replaced at build time by the plugin's transform hook.
//
// `options.strategy === 'client'` -> createApp    (fresh client render)
// otherwise                        -> createSSRApp (hydrates SSR markup)
import { createApp, createSSRApp } from 'vue';

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
    const factory = options && options.strategy === 'client' ? createApp : createSSRApp;
    factory(mod.default, props).mount(el);
}
