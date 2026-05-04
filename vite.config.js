import { defineConfig } from 'vite';
import coldspa from './coldspa/vite/plugin.js';

export default defineConfig({
    plugins: [
        coldspa({ frameworks: ['vue'] })
    ]
});

