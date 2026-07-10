// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// Site is published at https://yokeloop.github.io/yoke via the GitHub Actions
// workflow at .github/workflows/docs.yml.
// Pagefind search is enabled by default in Starlight — no flag needed.

export default defineConfig({
  site: 'https://yokeloop.github.io',
  base: '/yoke',

  integrations: [
    starlight({
      title: 'yoke',
      description:
        'Skills and slash-commands for Claude Code that ship a full dev loop.',
      social: {
        github: 'https://github.com/yokeloop/yoke',
      },
      sidebar: [
        { label: 'What is yoke?', link: '/what-is-yoke/' },
        { label: 'Install', link: '/install/' },
        { label: 'Concepts', link: '/concepts/' },
        {
          label: 'Flow',
          items: [
            { label: '/yoke:bootstrap', slug: 'skills/bootstrap' },
            { label: '/yoke:grill', slug: 'skills/grill' },
            { label: '/yoke:grill-docs', slug: 'skills/grill-docs' },
            { label: '/yoke:do', slug: 'skills/do' },
            { label: '/yoke:merge', slug: 'skills/merge' },
          ],
        },
        {
          label: 'Spec',
          items: [
            { label: '/yoke:prd', slug: 'skills/prd' },
            { label: '/yoke:issues', slug: 'skills/issues' },
          ],
        },
        {
          label: 'Git',
          items: [
            { label: '/yoke:gca', slug: 'skills/gca' },
            { label: '/yoke:gp', slug: 'skills/gp' },
            { label: '/yoke:pr', slug: 'skills/pr' },
          ],
        },
        {
          label: 'Utilities',
          items: [
            { label: '/yoke:review', slug: 'skills/review' },
            { label: '/yoke:journal', slug: 'skills/journal' },
            { label: '/yoke:handoff', slug: 'skills/handoff' },
            { label: '/yoke:help', slug: 'skills/help' },
          ],
        },
      ],
    }),
  ],
});
