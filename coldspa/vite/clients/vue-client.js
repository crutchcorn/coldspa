// Coldspa Vue client entry. Bundled by Vite via the coldspa plugin.
// __COLDSPA_GLOB__ is replaced at build time by the plugin's transform hook.
//
// Uses createSSRApp so .mount(el) HYDRATES if `el` already contains
// server-rendered HTML, or mounts fresh if the SSR sidecar wasn't available.
import { createSSRApp } from 'vue';

const components = import.meta.glob('__COLDSPA_GLOB__');

export async function mount(componentPath, el, props) {
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
    createSSRApp(mod.default, props).mount(el);
}
