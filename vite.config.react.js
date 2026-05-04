// React-only Vite config for the demos/react island demo.
// Run with: npm run vite:react
import { defineConfig } from 'vite';
import coldspa from 'coldspa/vite';

export default defineConfig({
    plugins: [
        coldspa({
            frameworks: ['react'],
            globs: {
                react: '/demos/react/**/*.{jsx,tsx}'
            }
        })
    ]
});
