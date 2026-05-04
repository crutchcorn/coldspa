// Coldspa SSR sidecar.
//
// CFML calls this over HTTP to render component HTML before sending the page.
//
// Endpoints:
//   POST /render/:framework
//     body: { componentPath: string, props: object }
//     200:  { html: string }
//     500:  { error: string }
//
// Modes:
//   - dev   (default if NODE_ENV !== 'production'): uses Vite's middleware-mode
//           dev server + ssrLoadModule. Picks up component changes without
//           rebuilding.
//   - prod: imports the built bundle from dist-ssr/ directly. Run
//           `npm run build:ssr` first.
//
// Env:
//   COLDSPA_SSR_PORT   default 5174
//   COLDSPA_SSR_HOST   default 0.0.0.0  (bind on all interfaces so CF running
//                                        in a container or on another machine
//                                        can reach the sidecar; restrict to
//                                        '127.0.0.1' for single-host dev)
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
    vue: '/coldspa/vite/clients/vue-ssr.js'
};
const SSR_ENTRIES_PROD = {
    vue: resolve(PROJECT_ROOT, 'dist-ssr', 'vue-ssr.js')
};

// --- module loading -----------------------------------------------------

let viteDevServer = null;     // dev only
const prodModuleCache = {};   // prod only

async function getRenderer(framework) {
    if (IS_PROD) {
        if (prodModuleCache[framework]) return prodModuleCache[framework];
        const path = SSR_ENTRIES_PROD[framework];
        if (!path) throw new Error(`Unknown framework "${framework}"`);
        // pathToFileURL so dynamic import works on Windows.
        const mod = await import(pathToFileURL(path).href);
        prodModuleCache[framework] = mod;
        return mod;
    }
    // Dev: lazy-init Vite middleware-mode server, ssrLoadModule per request.
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
        const { componentPath, props } = await readJsonBody(req);
        const renderer = await getRenderer(framework);
        const html = await renderer.render(componentPath, props ?? {});
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ html }));
    } catch (err) {
        // Log full stack server-side; send a short message to CF.
        console.error('[coldspa-ssr]', err);
        res.statusCode = 500;
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ error: String(err?.message || err) }));
    }
});

server.listen(PORT, HOST, () => {
    console.log(`[coldspa-ssr] listening on http://${HOST}:${PORT} (${IS_PROD ? 'prod' : 'dev'})`);
});
