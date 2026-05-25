// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	integrations: [
		starlight({
			title: 'Coldspa',
			logo: {
				src: "./public/favicon.svg",
				alt: "A bathtub made out of an iceburg",
			},
			favicon: "/favicon.svg",
			customCss: ["./src/styles/theme.css"],
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/crutchcorn/coldspa' }],
			sidebar: [
				{
					label: 'Guides',
					items: [
						{ label: 'Getting started',      slug: 'guides/getting-started' },
						{ label: 'Hydration strategies', slug: 'guides/hydration-strategies' },
						{ label: 'Slots',                slug: 'guides/slots' },
						{ label: 'Configuration',        slug: 'guides/configuration' },
						{ label: 'Docker & cross-host',  slug: 'guides/docker' },
					],
				},
			],
		}),
	],
});
