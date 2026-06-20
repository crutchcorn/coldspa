// Default Vite config -- includes both Vue and React, scanning demos/.
// Used by `npm run dev`, `npm run build`, and the SSR sidecar (`npm run ssr`).
//
// For a single-framework dev server, use vite.config.vue.js or
// vite.config.react.js via `npm run vite:vue` / `npm run vite:react`.
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import react from '@vitejs/plugin-react';
import coldspa from 'coldspa/vite';

export default defineConfig({
    plugins: [
        vue(),
        react(),
        coldspa({
            frameworks: ['vue', 'react'],
            globs: {
                vue:   '/demos/**/*.vue',
                react: '/demos/**/*.{jsx,tsx}'
            }
        })
    ]
});
