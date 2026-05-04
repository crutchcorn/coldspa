// Coldspa Vue client entry.
// Uses import.meta.glob so Vite knows about all island components at build time
// and bundles each as its own dynamic chunk. In dev, Vite serves them directly.
import { createApp } from 'vue';

// Match any .vue under src/. Adjust the glob if you keep components elsewhere.
const components = import.meta.glob('/src/**/*.vue');

export async function mount(componentPath, el, props) {
    if (!el) return;
    const loader = components[componentPath];
    if (!loader) {
        console.error(
            `[Coldspa] No Vue component registered for path "${componentPath}". ` +
            `Make sure it matches the glob in coldspa/renderers/vue-client.js.`
        );
        return;
    }
    const mod = await loader();
    createApp(mod.default, props).mount(el);
}
