#!/usr/bin/env node
// Game exporter: the SSOT markdown corpus -> build/codex.json (consumed by Godot).
// Reads the SAME content/ the Astro web build reads, and validates against the SAME
// schema (../schema/entrySchema.mjs). Neither consumer owns the data. See ARCHITECTURE.md §5.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, relative, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import matter from 'gray-matter';
import { entrySchema } from '../schema/entrySchema.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const ENTRIES_DIR = join(ROOT, 'content', 'entries');
const OUT = join(ROOT, 'build', 'codex.json');

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (name.endsWith('.md')) out.push(p);
  }
  return out;
}

// Split the prose body into its canonical H2 sections (Story / History / Primary text / Game lens).
function splitSections(body) {
  const buf = { _intro: [] };
  let current = '_intro';
  for (const line of body.split('\n')) {
    const m = line.match(/^##\s+(.+?)\s*$/);
    if (m) { current = m[1].trim(); buf[current] = []; }
    else { (buf[current] ||= []).push(line); }
  }
  const out = {};
  for (const [k, v] of Object.entries(buf)) {
    const text = v.join('\n').trim();
    if (text) out[k] = text;
  }
  return out;
}

const files = walk(ENTRIES_DIR);
const entries = [];
const errors = [];

for (const f of files) {
  const { data, content } = matter(readFileSync(f, 'utf8'));
  const parsed = entrySchema.safeParse(data);
  if (!parsed.success) {
    errors.push(`SCHEMA  ${relative(ROOT, f)}: ` +
      parsed.error.issues.map(i => `${i.path.join('.')} — ${i.message}`).join('; '));
    continue;
  }
  const e = parsed.data;
  if (e.id !== basename(f, '.md')) {
    errors.push(`ID      ${relative(ROOT, f)}: frontmatter id "${e.id}" != filename`);
  }
  entries.push({ ...e, sections: splitSections(content), _file: relative(ROOT, f) });
}

// Referential integrity — stub-aware: a stub still "exists". Build fails only on ids that exist NOWHERE.
const ids = new Set(entries.map(e => e.id));
for (const e of entries) {
  const refs = [];
  if (e.origin) refs.push(['origin', e.origin]);
  if (e.seat) refs.push(['seat', e.seat]);
  e.related.forEach(r => refs.push(['related', r]));
  for (const [k, arr] of Object.entries(e.relationships)) arr.forEach(v => refs.push([`relationships.${k}`, v]));
  e.participants.forEach(p => refs.push(['participants', p]));
  if (e.movement) {
    e.movement.who.forEach(w => refs.push(['movement.who', w]));
    if (e.movement.from) refs.push(['movement.from', e.movement.from]);
    if (e.movement.to) refs.push(['movement.to', e.movement.to]);
    e.movement.route.forEach(w => refs.push(['movement.route', w]));
  }
  for (const [field, target] of refs) {
    if (!ids.has(target)) errors.push(`LINK    ${e.id}: ${field} -> "${target}" exists nowhere (needs an entry or a stub)`);
  }
}

if (errors.length) {
  console.error(`\n✗ Export FAILED — ${errors.length} error(s):\n` + errors.map(x => '   - ' + x).join('\n') + '\n');
  process.exit(1);
}

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify({
  generated: new Date().toISOString(),
  count: entries.length,
  entries: entries.sort((a, b) => a.id.localeCompare(b.id)),
}, null, 2), 'utf8');

const stubs = entries.filter(e => e.status === 'stub').map(e => e.id);
console.log(`✓ Exported ${entries.length} entries -> ${relative(ROOT, OUT)}`);
console.log(`  full: ${entries.filter(e => e.status !== 'stub').map(e => e.id).join(', ') || 'none'}`);
console.log(`  stubs (coverage TODO): ${stubs.join(', ') || 'none'}`);
