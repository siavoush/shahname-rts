import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
// The SAME schema the game exporter validates against (../../schema/entrySchema.mjs).
// Astro derives the entry `id` from the filename, so we omit `id` from the validated frontmatter.
import { entrySchema } from '../../schema/entrySchema.mjs';

const entries = defineCollection({
  loader: glob({ pattern: '**/*.md', base: '../content/entries' }),
  schema: entrySchema.omit({ id: true }),
});

export const collections = { entries };
