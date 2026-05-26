#!/usr/bin/env node
// Game exporter: the SSOT markdown corpus -> build/codex.json (consumed by Godot).
// Reads the SAME content/ the Astro web build reads, and validates against the SAME
// schema via tooling/validate.mjs — neither consumer owns the data, and link
// integrity is the shared rule. See ARCHITECTURE.md §5.
import { writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateCorpus } from '../tooling/validate.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'build', 'codex.json');

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

const { entries, errors, stubs } = validateCorpus();

if (errors.length) {
  console.error(`\n✗ Export FAILED — ${errors.length} error(s):\n` + errors.map((x) => '   - ' + x).join('\n') + '\n');
  process.exit(1);
}

const records = entries
  .map(({ data, body, file }) => ({ ...data, sections: splitSections(body), _file: file }))
  .sort((a, b) => a.id.localeCompare(b.id));

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify({
  generated: new Date().toISOString(),
  count: records.length,
  entries: records,
}, null, 2), 'utf8');

const full = records.filter((e) => e.status !== 'stub').map((e) => e.id);
console.log(`✓ Exported ${records.length} entries -> ${relative(ROOT, OUT)}`);
console.log(`  full: ${full.join(', ') || 'none'}`);
console.log(`  stubs (coverage TODO): ${stubs.join(', ') || 'none'}`);
