// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	integrations: [
		starlight({
			title: 'Coldspa',
			logo: {
				src: "./public/bathtub.png",
				alt: "A bathtub emoji",
			},
			favicon: "./public/bathtub.png",
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/crutchcorn/coldspa' }],
			sidebar: [
				{
					label: 'Guides',
					autogenerate: { directory: 'docs/guides' },
				},
			],
		}),
	],
});
