// Vue-only Vite config for the demos/vue island demo.
// Run with: npm run vite:vue
import { defineConfig } from 'vite';
import coldspa from './coldspa/vite/plugin.js';

export default defineConfig({
    plugins: [
        coldspa({
            frameworks: ['vue'],
            globs: {
                vue: '/demos/vue/**/*.vue'
            }
        })
    ]
});
