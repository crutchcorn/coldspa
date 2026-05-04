import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { resolve } from 'path';

export default defineConfig({
    plugins: [vue()],
    server: {
        port: 5173,
        cors: true,
        origin: 'http://localhost:5173'
    },
    build: {
        manifest: true,
        outDir: 'dist',
        rollupOptions: {
            input: {
                'src/App.vue': resolve(__dirname, 'src/App.vue')
            }
        }
    }
});
