// Coldspa Vite plugin.
//
// Encapsulates everything Vite needs to support cf_Island:
//   - Loads framework sub-plugins (@vitejs/plugin-vue, @vitejs/plugin-react)
//   - Registers the matching client-entry shims as build inputs
//   - Sets manifest output, base path, dev server port/CORS for the CF integration
//   - Forces preserveEntrySignatures so the entry chunks aren't tree-shaken away
//
// Usage:
//   import { defineConfig } from 'vite';
//   import coldspa from './coldspa/vite/plugin.js';
//
//   export default defineConfig({
//     plugins: [coldspa({ frameworks: ['vue'] })]
//   });
//
// Options:
//   frameworks   string[]   default ['vue']     -- which renderers to wire up
//   vitePort     number     default 5173        -- dev server port (must match IslandConfig)
//   outDir       string     default 'dist'      -- production output dir
//   base         string     default '/dist/'    -- public path for built assets (build only)

import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

const FRAMEWORK_CLIENTS = {
    vue:   resolve(__dirname, 'clients/vue-client.js'),
    react: resolve(__dirname, 'clients/react-client.js')
};

// Framework sub-plugins are imported lazily so consumers only need to install
// the @vitejs/plugin-* packages for the frameworks they actually use.
async function loadFrameworkPlugin(name) {
    switch (name) {
        case 'vue': {
            const mod = await import('@vitejs/plugin-vue');
            return mod.default();
        }
        case 'react': {
            const mod = await import('@vitejs/plugin-react');
            return mod.default();
        }
        default:
            throw new Error(`[coldspa] Unknown framework "${name}". Supported: vue, react.`);
    }
}

export default function coldspa(options = {}) {
    const frameworks = options.frameworks ?? ['vue'];
    const vitePort   = options.vitePort   ?? 5173;
    const outDir     = options.outDir     ?? 'dist';
    const baseProd   = options.base       ?? '/dist/';

    for (const fw of frameworks) {
        if (!(fw in FRAMEWORK_CLIENTS)) {
            throw new Error(`[coldspa] Unknown framework "${fw}". Supported: ${Object.keys(FRAMEWORK_CLIENTS).join(', ')}.`);
        }
    }

    // Build the rollup input map from selected frameworks.
    const input = {};
    for (const fw of frameworks) {
        input[`${fw}-client`] = FRAMEWORK_CLIENTS[fw];
    }

    // Load sub-plugins eagerly (Vite expects a flat plugin array synchronously,
    // but plugins themselves can be Promises — we resolve them via a wrapper).
    const subPluginsPromise = Promise.all(frameworks.map(loadFrameworkPlugin));

    return [
        // Spread the resolved sub-plugins into the array. Vite supports promises
        // at the top level of the plugins array.
        subPluginsPromise.then(plugins => plugins),
        {
            name: 'coldspa',
            config(_userConfig, { command }) {
                return {
                    base: command === 'build' ? baseProd : '/',
                    server: {
                        port: vitePort,
                        cors: true,
                        origin: `http://localhost:${vitePort}`
                    },
                    build: {
                        manifest: true,
                        outDir,
                        rollupOptions: {
                            preserveEntrySignatures: 'strict',
                            input
                        }
                    }
                };
            }
        }
    ];
}
