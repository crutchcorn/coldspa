// Vue-only Vite config for the demos/vue island demo.
// Run with: npm run vite:vue
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import coldspa from 'coldspa/vite';

export default defineConfig({
    plugins: [
        vue(),
        coldspa({
            frameworks: ['vue'],
            globs: {
                vue: '/demos/vue/**/*.vue'
            }
        })
    ]
});
