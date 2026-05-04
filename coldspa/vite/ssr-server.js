#!/usr/bin/env node
// Coldspa SSR sidecar.
//
// CFML calls this over HTTP to render component HTML before sending the page.
//
// Endpoints:
//   POST /render/:framework
//     body: { componentPath: string, props: object }
//     200:  { html: string, css: string }
//     500:  { error: string }
//
// Modes:
//   - dev   (default if NODE_ENV !== 'production'): uses Vite's middleware-mode
//           dev server + ssrLoadModule. Picks up component changes without
//           rebuilding. Component CSS is collected from Vite's module graph
//           and returned in the `css` field so CF can inline a <style> tag.
//   - prod: imports the built bundle from dist-ssr/ directly. Run
//           `npm run build:ssr` first. CSS is served via <link> tags from the
//           client manifest (handled in Island.cfm).
//
// Env:
//   COLDSPA_SSR_PORT   default 5174
//   COLDSPA_SSR_HOST   default 0.0.0.0
//   NODE_ENV           'production' switches to prod mode

import { createServer as createHttpServer } from 'http';
import { fileURLToPath, pathToFileURL } from 'url';
import { dirname, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, '..', '..'); // webroot
const PORT = Number(process.env.COLDSPA_SSR_PORT || 5174);
const HOST = process.env.COLDSPA_SSR_HOST || '0.0.0.0';
const IS_PROD = process.env.NODE_ENV === 'production';

// Map :framework path segment -> SSR module entry path / id
const SSR_ENTRIES_DEV = {
    vue:   '/coldspa/vite/clients/vue-ssr.js',
    react: '/coldspa/vite/clients/react-ssr.js'
};
const SSR_ENTRIES_PROD = {
    vue:   resolve(PROJECT_ROOT, 'dist-ssr', 'vue-ssr.js'),
    react: resolve(PROJECT_ROOT, 'dist-ssr', 'react-ssr.js')
};

// --- module loading -----------------------------------------------------

let viteDevServer = null;     // dev only
const prodModuleCache = {};   // prod only

async function getRenderer(framework) {
    if (IS_PROD) {
        if (prodModuleCache[framework]) return prodModuleCache[framework];
        const path = SSR_ENTRIES_PROD[framework];
        if (!path) throw new Error(`Unknown framework "${framework}"`);
        const mod = await import(pathToFileURL(path).href);
        prodModuleCache[framework] = mod;
        return mod;
    }
    if (!viteDevServer) {
        const { createServer } = await import('vite');
        viteDevServer = await createServer({
            root: PROJECT_ROOT,
            server: { middlewareMode: true },
            appType: 'custom'
        });
    }
    const id = SSR_ENTRIES_DEV[framework];
    if (!id) throw new Error(`Unknown framework "${framework}"`);
    return await viteDevServer.ssrLoadModule(id);
}

// --- CSS collection (dev) -----------------------------------------------

function isCssId(s) {
    if (!s) return false;
    return /\.(css|scss|sass|less|styl|stylus|pcss|postcss)($|\?)/.test(s)
        || /[?&]lang\.(css|scss|sass|less|styl|stylus|pcss|postcss)/.test(s)
        || /[?&]vue&type=style/.test(s);
}

function unquote(literal) {
    // Decode a JS source-level string/template literal.
    try { return Function(`return (${literal})`)(); } catch { return ''; }
}

function extractCssFromModule(code) {
    // Vite's CSS HMR module wraps the raw CSS in __vite__updateStyle(id, "...").
    let m = code.match(/__vite__updateStyle\([^,]+,\s*((?:`|")[\s\S]*?(?:`|"))\)/);
    if (m) return unquote(m[1]) || '';
    // Fallback for other shapes Vite may emit.
    m = code.match(/const\s+__vite__css\s*=\s*((?:`|")[\s\S]*?(?:`|"))/);
    if (m) return unquote(m[1]) || '';
    return '';
}

// Walks the SSR module graph from a given component URL and returns the
// concatenated CSS of every (transitively) imported style module. Without
// this, scoped Vue styles flash in only after the client bundle hydrates.
async function collectCssDev(componentPath) {
    if (!viteDevServer) return '';
    // Make sure the module is in the SSR graph.
    try { await viteDevServer.ssrLoadModule(componentPath); } catch { /* ignore */ }

    const root = await viteDevServer.moduleGraph.getModuleByUrl(componentPath, true);
    if (!root) return '';

    const styles = new Map();
    const seen = new Set();

    async function walk(mod) {
        if (!mod) return;
        const key = mod.id || mod.url;
        if (!key || seen.has(key)) return;
        seen.add(key);

        if (isCssId(mod.id) || isCssId(mod.url)) {
            try {
                const r = await viteDevServer.transformRequest(mod.url || mod.id, { ssr: false });
                if (r && r.code) {
                    const css = extractCssFromModule(r.code);
                    if (css) styles.set(key, css);
                }
            } catch {
                // ignore transform errors -- skip this file
            }
        }

        const next = mod.ssrImportedModules || mod.importedModules;
        if (next) {
            for (const child of next) await walk(child);
        }
    }

    await walk(root);
    return Array.from(styles.values()).join('\n');
}

// --- http ---------------------------------------------------------------

async function readJsonBody(req) {
    let body = '';
    for await (const chunk of req) body += chunk;
    return body ? JSON.parse(body) : {};
}

const server = createHttpServer(async (req, res) => {
    if (req.method !== 'POST') {
        res.statusCode = 405;
        res.end();
        return;
    }
    const m = req.url.match(/^\/render\/([a-z]+)$/);
    if (!m) {
        res.statusCode = 404;
        res.end();
        return;
    }
    const framework = m[1];

    try {
        const { componentPath, props, slotHtml, namedSlots } = await readJsonBody(req);
        const renderer = await getRenderer(framework);
        const html = await renderer.render(componentPath, props ?? {}, slotHtml ?? '', namedSlots ?? {});
        // Dev: collect inline CSS so the page has component styles before
        // hydration. Prod: handled via <link> from the client manifest.
        const css = IS_PROD ? '' : await collectCssDev(componentPath);
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ html, css }));
    } catch (err) {
        console.error('[coldspa-ssr]', err);
        res.statusCode = 500;
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ error: String(err?.message || err) }));
    }
});

server.listen(PORT, HOST, () => {
    console.log(`[coldspa-ssr] listening on http://${HOST}:${PORT} (${IS_PROD ? 'prod' : 'dev'})`);
});
