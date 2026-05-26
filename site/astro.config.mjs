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
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/yokeloop/yoke',
        },
      ],
      sidebar: [
        { label: 'What is yoke?', slug: 'what-is-yoke' },
        { label: 'Install', slug: 'install' },
        { label: 'Concepts', slug: 'concepts' },
        {
          label: 'Dev loop',
          items: [
            { label: '/yoke:task', slug: 'skills/task' },
            { label: '/yoke:plan', slug: 'skills/plan' },
            { label: '/yoke:do', slug: 'skills/do' },
            { label: '/yoke:fix', slug: 'skills/fix' },
            { label: '/yoke:review', slug: 'skills/review' },
          ],
        },
        {
          label: 'Git',
          items: [
            { label: '/yoke:gca', slug: 'skills/gca' },
            { label: '/yoke:gp', slug: 'skills/gp' },
            { label: '/yoke:pr', slug: 'skills/pr' },
            { label: '/yoke:gst', slug: 'skills/gst' },
          ],
        },
        {
          label: 'Analysis',
          items: [
            { label: '/yoke:explore', slug: 'skills/explore' },
            { label: '/yoke:grill', slug: 'skills/grill' },
            { label: '/yoke:grill-docs', slug: 'skills/grill-docs' },
          ],
        },
        {
          label: 'Meta',
          items: [
            { label: '/yoke:prd', slug: 'skills/prd' },
            { label: '/yoke:issues', slug: 'skills/issues' },
            { label: '/yoke:handoff', slug: 'skills/handoff' },
            { label: '/yoke:bootstrap', slug: 'skills/bootstrap' },
            { label: '/yoke:help', slug: 'skills/help' },
          ],
        },
        {
          label: 'Plugin dev',
          items: [{ label: '/yoke:sync-docs', slug: 'skills/sync-docs' }],
        },
      ],
    }),
  ],
});
