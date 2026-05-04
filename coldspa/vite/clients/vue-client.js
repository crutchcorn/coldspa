// Coldspa Vue client entry. Bundled by Vite via the coldspa plugin.
import { createApp } from 'vue';

const components = import.meta.glob('/src/**/*.vue');

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
    createApp(mod.default, props).mount(el);
}
