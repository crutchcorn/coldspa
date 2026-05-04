// Coldspa Vite plugin.
//
// Encapsulates everything Vite needs to support cf_Island:
//   - Loads framework sub-plugins (@vitejs/plugin-vue, @vitejs/plugin-react)
//   - Registers the matching client-entry shims as build inputs
//   - Sets manifest output, base path, dev server port/CORS for the CF integration
//   - Forces preserveEntrySignatures so the entry chunks aren't tree-shaken away
//   - Substitutes the user's component glob into the client entries at transform time
//
// Usage (simple):
//   coldspa({ frameworks: ['vue'] })
//
// Usage (custom component locations):
//   coldspa({
//     frameworks: ['vue', 'react'],
//     globs: {
//       vue:   '/app/**/*.vue',
//       react: ['/app/**/*.jsx', '/app/**/*.tsx']
//     }
//   })
//
// Options:
//   frameworks   string[]                    default ['vue']
//   globs        Record<framework, string|string[]>  per-framework component glob(s)
//   vitePort     number                      default 5173
//   outDir       string                      default 'dist'
//   base         string                      default '/dist/'  (build only)

import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Vite normalizes module ids to forward slashes on all platforms; do the same
// here so our id-based lookups work on Windows.
const toViteId = (p) => resolve(p).split('\\').join('/');

const FRAMEWORK_CLIENTS = {
    vue:   toViteId(resolve(__dirname, 'clients/vue-client.js')),
    react: toViteId(resolve(__dirname, 'clients/react-client.js'))
};

const DEFAULT_GLOBS = {
    vue:   '/src/**/*.vue',
    react: '/src/**/*.{jsx,tsx}'
};

const GLOB_PLACEHOLDER = '__COLDSPA_GLOB__';

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

// Renders a glob option as the literal source text of an import.meta.glob argument:
//   "/src/**/*.vue"           -> '/src/**/*.vue'
//   ["/a/**", "/b/**"]        -> ["/a/**","/b/**"]
function renderGlobLiteral(glob) {
    if (Array.isArray(glob)) {
        return JSON.stringify(glob);
    }
    return JSON.stringify(glob);
}

export default function coldspa(options = {}) {
    const frameworks = options.frameworks ?? ['vue'];
    const vitePort   = options.vitePort   ?? 5173;
    const outDir     = options.outDir     ?? 'dist';
    const baseProd   = options.base       ?? '/dist/';
    const userGlobs  = options.globs      ?? {};

    for (const fw of frameworks) {
        if (!(fw in FRAMEWORK_CLIENTS)) {
            throw new Error(`[coldspa] Unknown framework "${fw}". Supported: ${Object.keys(FRAMEWORK_CLIENTS).join(', ')}.`);
        }
    }

    // Resolve final glob per framework, with absolute client-entry paths as keys
    // for fast lookup in the transform hook.
    const globsByClientPath = {};
    const input = {};
    for (const fw of frameworks) {
        const clientPath = FRAMEWORK_CLIENTS[fw];
        input[`${fw}-client`] = clientPath;
        globsByClientPath[clientPath] = userGlobs[fw] ?? DEFAULT_GLOBS[fw];
    }

    const subPluginsPromise = Promise.all(frameworks.map(loadFrameworkPlugin));

    return [
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
            },

            // Replace the glob placeholder in our client entries with the
            // user-configured glob. Must run BEFORE vite:import-glob (which is
            // what actually transforms import.meta.glob() into the dynamic
            // import map).
            enforce: 'pre',
            transform(code, id) {
                // id may include a query string (?import, ?used, etc); strip it
                const cleanId = id.split('?')[0];
                const glob = globsByClientPath[cleanId];
                if (!glob) return null;
                if (!code.includes(GLOB_PLACEHOLDER)) return null;

                // Replace the literal "'__COLDSPA_GLOB__'" (with quotes) in the
                // source with the rendered glob literal. This keeps the result
                // a valid call to import.meta.glob(...).
                const replaced = code.replace(
                    `'${GLOB_PLACEHOLDER}'`,
                    renderGlobLiteral(glob)
                );
                return { code: replaced, map: null };
            }
        }
    ];
}

