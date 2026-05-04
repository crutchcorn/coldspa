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
import { existsSync, readFileSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Vite normalizes module ids to forward slashes on all platforms; do the same
// here so our id-based lookups work on Windows.
const toViteId = (p) => resolve(p).split('\\').join('/');

const FRAMEWORK_CLIENTS = {
    vue:   toViteId(resolve(__dirname, 'clients/vue-client.js')),
    react: toViteId(resolve(__dirname, 'clients/react-client.js'))
};

// SSR entries (only Vue is implemented today; React SSR is a TODO).
const FRAMEWORK_SSR = {
    vue: toViteId(resolve(__dirname, 'clients/vue-ssr.js'))
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

// Discover the externally-reachable Vite host so we can auto-expose the dev
// server when CF / the browser hit it via something other than localhost
// (e.g. host.docker.internal in a containerized CF setup).
//
// Sources, highest priority first:
//   1. COLDSPA_VITE_URL env var
//   2. coldspa.config.json -> viteUrl
//
// Returns { hostname, needsExternal } or null if only localhost is in use.
function discoverExternalHost(projectRoot) {
    const sources = [];
    if (process.env.COLDSPA_VITE_URL) {
        sources.push(process.env.COLDSPA_VITE_URL);
    }
    const cfgPath = resolve(projectRoot, 'coldspa.config.json');
    if (existsSync(cfgPath)) {
        try {
            const cfg = JSON.parse(readFileSync(cfgPath, 'utf8'));
            if (cfg && typeof cfg.viteUrl === 'string') sources.push(cfg.viteUrl);
        } catch {
            // Malformed JSON -- ignore and fall through.
        }
    }

    for (const src of sources) {
        try {
            const url = new URL(src);
            const host = url.hostname;
            if (host && host !== 'localhost' && host !== '127.0.0.1' && host !== '::1') {
                return { hostname: host, needsExternal: true };
            }
        } catch {
            // Invalid URL -- skip.
        }
    }
    return null;
}

// Build the Vite `server` config block, opening up host binding + the host
// allowlist when an external host is detected.
function serverConfig(vitePort, projectRoot) {
    const external = discoverExternalHost(projectRoot);
    const base = {
        port: vitePort,
        cors: true,
        origin: `http://localhost:${vitePort}`
    };
    if (!external) return base;

    return {
        ...base,
        // Bind on all interfaces so requests from other hosts (e.g. a CF
        // container reaching the host's Vite via host.docker.internal) work.
        host: true,
        // Vite >=5.4 enforces a host header allowlist. Permit the discovered
        // hostname so cross-host requests aren't rejected with 403.
        allowedHosts: [external.hostname],
        // Match origin so generated asset URLs (HMR, etc.) point at the right
        // host instead of localhost.
        origin: `http://${external.hostname}:${vitePort}`,
        hmr: {
            host: external.hostname,
            clientPort: vitePort
        }
    };
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
    const ssrInput = {};
    for (const fw of frameworks) {
        const clientPath = FRAMEWORK_CLIENTS[fw];
        input[`${fw}-client`] = clientPath;
        globsByClientPath[clientPath] = userGlobs[fw] ?? DEFAULT_GLOBS[fw];

        // SSR entry (if framework supports it). Same glob applies.
        if (FRAMEWORK_SSR[fw]) {
            const ssrPath = FRAMEWORK_SSR[fw];
            ssrInput[`${fw}-ssr`] = ssrPath;
            globsByClientPath[ssrPath] = userGlobs[fw] ?? DEFAULT_GLOBS[fw];
        }
    }

    // Detect SSR build mode. Runs `vite build` with build.ssr=true and emits
    // unhashed flat files into dist-ssr/ so the Node sidecar can require them.
    const isSsrBuild = process.env.COLDSPA_SSR === '1';

    const subPluginsPromise = Promise.all(frameworks.map(loadFrameworkPlugin));

    return [
        subPluginsPromise.then(plugins => plugins),
        {
            name: 'coldspa',

            config(_userConfig, { command }) {
                if (isSsrBuild) {
                    return {
                        // SSR builds don't need a public base path; output is
                        // consumed by Node, not the browser.
                        build: {
                            ssr: true,
                            outDir: `${outDir}-ssr`,
                            emptyOutDir: true,
                            rollupOptions: {
                                preserveEntrySignatures: 'strict',
                                input: ssrInput,
                                // Flat, unhashed names so the sidecar can
                                // import a stable path like ./vue-ssr.js.
                                output: {
                                    entryFileNames: '[name].js',
                                    chunkFileNames: '[name].js',
                                    assetFileNames: '[name][extname]'
                                }
                            }
                        }
                    };
                }
                return {
                    base: command === 'build' ? baseProd : '/',
                    server: serverConfig(vitePort, _userConfig.root || process.cwd()),
                    // Exclude our client entries from Vite's dep pre-scan.
                    // The scanner runs an esbuild pass that doesn't go through
                    // our transform hook, so it sees the raw __COLDSPA_GLOB__
                    // placeholder and bails. These files are entry points
                    // anyway -- they don't belong in the optimized deps cache.
                    optimizeDeps: {
                        entries: [],
                        exclude: Object.values(FRAMEWORK_CLIENTS).concat(
                            Object.values(FRAMEWORK_SSR)
                        )
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

