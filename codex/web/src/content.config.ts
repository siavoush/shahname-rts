import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { basename } from 'node:path';
// The SAME schema the game exporter validates against (../../schema/entrySchema.mjs).
// The exporter treats `id` as the file's basename (e.g. `rostam` for `people/rostam.md`);
// all cross-links, relationships, and wiki-links in the corpus use that bare form. We must
// match it here, or Astro's default (path-relative-to-base, e.g. `people/rostam`) breaks
// the single-segment `[id].astro` route and the [[wiki-link]] resolution.
import { entrySchema } from '../../schema/entrySchema.mjs';

const entries = defineCollection({
  loader: glob({
    pattern: '**/*.md',
    base: '../content/entries',
    generateId: ({ entry }) => basename(entry, '.md'),
  }),
  schema: entrySchema.omit({ id: true }),
});

export const collections = { entries };
