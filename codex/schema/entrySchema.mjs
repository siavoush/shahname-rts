// Canonical Codex entry schema — the SINGLE definition honored by BOTH consumers:
//   - the Astro web build  (web/src/content.config.ts imports this, omitting `id`)
//   - the game exporter    (export/export.mjs imports this to validate + normalize)
// See ../ARCHITECTURE.md §3 and ../CONVENTIONS.md.
import { z } from 'zod';

const id = z.string().regex(/^[a-z0-9-]+$/, 'ids are lowercase-kebab slugs');

const sourceRef = z.object({
  ref: z.string(),                         // → content/sources.yaml id (e.g. "ganjoor")
  loc: z.string().optional(),              // human locator (section / beyt)
  url: z.string().url().optional(),
});

const verse = z.object({
  fa: z.string(),                          // verbatim Persian — fetched from Ganjoor, never recalled
  translit: z.string().optional(),
  en: z.string().optional(),
  source: sourceRef,
});

const mediaItem = z.object({
  kind: z.enum(['image', 'audio']),
  url: z.string(),
  caption: z.string().optional(),
  source: z.string().optional(),           // → sources.yaml id
  license: z.string(),                     // only public-domain / open-access ships in-game
});

export const ENTRY_TYPES = ['person', 'place', 'event', 'concept', 'dynasty', 'creature', 'artifact', 'passage', 'faction', 'unit', 'building', 'mechanic'];
export const AGES = ['pishdadian', 'kayanian', 'sasanian', 'meta'];
export const REGISTERS = ['myth', 'legend', 'history'];

export const entrySchema = z.object({
  id,                                       // canonical slug; MUST equal the filename. (Astro omits this and derives it.)
  type: z.enum(ENTRY_TYPES),
  title: z.string(),
  title_fa: z.string().optional(),
  aka: z.array(z.string()).default([]),
  age: z.enum(AGES).optional(),             // optional: places/concepts/artifacts may be ageless
  register: z.enum(REGISTERS).optional(),   // drives timeline colour (myth/legend/history seam)
  summary: z.string(),                      // one line; powers hovercards AND the in-game tooltip

  chronology: z.object({
    mythic_seq: z.number().int().optional(),
    historical: z.object({ start: z.number().int(), end: z.number().int() }).nullable().optional(),
  }).optional(),

  // PEOPLE: static anchors only — trajectory is DERIVED from events (see ARCHITECTURE §3.4)
  origin: id.optional(),
  seat: id.optional(),

  // PLACES
  geo: z.object({
    region: id.optional(),
    coords: z.tuple([z.number(), z.number()]).optional(),   // Leaflet CRS.Simple [y, x]
  }).optional(),

  // EVENTS
  participants: z.array(id).default([]),
  movement: z.object({
    who: z.array(id),
    from: id.optional(),
    to: id.optional(),
    route: z.array(id).default([]),
  }).optional(),

  // typed relationship edges; every value is an entry id (referential check at build, stub-aware)
  // NB: two-arg z.record(key, value) is compatible with BOTH zod v3 (export) and zod v4 (Astro).
  relationships: z.record(z.string(), z.array(id)).default({}),

  primary_text: z.array(verse).default([]),

  game: z.object({
    maps_to: z.array(z.string()).default([]),   // soft refs into game/ design — NOT validated here
    anchor_category: z.string().nullable().optional(),
  }).optional(),

  media: z.array(mediaItem).default([]),
  sources: z.array(z.string()).default([]),     // → sources.yaml ids
  related: z.array(id).default([]),
  status: z.enum(['stub', 'draft', 'complete']).default('stub'),
  tags: z.array(z.string()).default([]),
});

export default entrySchema;
