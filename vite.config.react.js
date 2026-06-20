// React-only Vite config for the demos/react island demo.
// Run with: npm run vite:react
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import coldspa from 'coldspa/vite';

export default defineConfig({
    plugins: [
        react(),
        coldspa({
            frameworks: ['react'],
            globs: {
                react: '/demos/react/**/*.{jsx,tsx}'
            }
        })
    ]
});
