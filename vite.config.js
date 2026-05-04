import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { resolve } from 'path';

export default defineConfig(({ command }) => ({
    plugins: [vue()],
    // In production builds, assets live under /dist/ on the CF server, so all
    // built URLs (dynamic imports, CSS preloads, etc.) need to be prefixed.
    // In dev, the Vite server serves from root.
    base: command === 'build' ? '/dist/' : '/',
    server: {
        port: 5173,
        cors: true,
        origin: 'http://localhost:5173'
    },
    build: {
        manifest: true,
        outDir: 'dist',
        rollupOptions: {
            // Force entries to keep their export signatures even if they look
            // tree-shakeable. Without this, Rollup may emit empty entry chunks.
            preserveEntrySignatures: 'strict',
            // Only the client entries are explicit inputs. User components
            // are picked up automatically via import.meta.glob inside them.
            input: {
                'vue-client': resolve(__dirname, 'coldspa/renderers/vue-client.js'),
                'react-client': resolve(__dirname, 'coldspa/renderers/react-client.js')
            }
        }
    }
}));
