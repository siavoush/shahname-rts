#!/usr/bin/env node
// validate.mjs — standalone link-integrity validator for the entry corpus.
//
// Walks content/entries/**, parses every .md via the shared schema, and reports:
//   - SCHEMA errors      (frontmatter fails entrySchema)
//   - ID    errors       (frontmatter `id` != filename basename)
//   - LINK  errors       (id referenced from a reference-bearing field but exists
//                         NOWHERE — stub-aware: a stub still "exists")
//   - Coverage report    (outstanding stubs)
//
// Exits 0 on clean, non-zero on any hard error. Built so BOTH the exporter
// (export/export.mjs) and a CI step call the same logic — the exporter
// imports `validateCorpus()` from here; the standalone CLI runs `main()`.
//
// Usage:
//   node tooling/validate.mjs              # full report to stdout
//   node tooling/validate.mjs --quiet      # only print on failure
//   node tooling/validate.mjs --json       # machine-readable output

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, basename, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import matter from 'gray-matter';
import { entrySchema } from '../schema/entrySchema.mjs';

const SELF_DIR = dirname(fileURLToPath(import.meta.url));
const CODEX_ROOT = join(SELF_DIR, '..');
const DEFAULT_ENTRIES_DIR = join(CODEX_ROOT, 'content', 'entries');

// --- shared core ----------------------------------------------------------

function walkMd(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walkMd(p));
    else if (name.endsWith('.md')) out.push(p);
  }
  return out;
}

// Collect every reference-bearing field on an entry. Mirrors the exporter's
// integrity check, plus geo.region (which the exporter currently misses).
// Returns array of [field-path-string, target-id].
function collectRefs(e) {
  const refs = [];
  if (e.origin) refs.push(['origin', e.origin]);
  if (e.seat) refs.push(['seat', e.seat]);
  if (e.geo && e.geo.region) refs.push(['geo.region', e.geo.region]);
  for (const r of e.related) refs.push(['related', r]);
  for (const [k, arr] of Object.entries(e.relationships)) {
    for (const v of arr) refs.push([`relationships.${k}`, v]);
  }
  for (const p of e.participants) refs.push(['participants', p]);
  if (e.movement) {
    for (const w of e.movement.who) refs.push(['movement.who', w]);
    if (e.movement.from) refs.push(['movement.from', e.movement.from]);
    if (e.movement.to) refs.push(['movement.to', e.movement.to]);
    for (const w of e.movement.route) refs.push(['movement.route', w]);
  }
  return refs;
}

/**
 * Validate the corpus. Pure function — no console output, no exit.
 * The CLI prints + exits; the exporter consumes the returned entries.
 *
 * @param {{entriesDir?: string}} opts
 * @returns {{entries: Array<{data, body, file}>, errors: string[], stubs: string[]}}
 */
export function validateCorpus({ entriesDir = DEFAULT_ENTRIES_DIR } = {}) {
  const files = walkMd(entriesDir);
  const entries = [];
  const errors = [];

  // Pass 1: parse + schema-validate each file; collect entries.
  for (const f of files) {
    const rel = relative(CODEX_ROOT, f);
    const { data, content } = matter(readFileSync(f, 'utf8'));
    const parsed = entrySchema.safeParse(data);
    if (!parsed.success) {
      errors.push(
        `SCHEMA  ${rel}: ` +
        parsed.error.issues.map((i) => `${i.path.join('.')} — ${i.message}`).join('; ')
      );
      continue;
    }
    const e = parsed.data;
    if (e.id !== basename(f, '.md')) {
      errors.push(`ID      ${rel}: frontmatter id "${e.id}" != filename basename`);
      // Still include the entry — id mismatch alone shouldn't suppress link checks.
    }
    entries.push({ data: e, body: content, file: rel });
  }

  // Pass 2: stub-aware referential integrity. A stub still "exists".
  const ids = new Set(entries.map((x) => x.data.id));
  for (const { data: e } of entries) {
    for (const [field, target] of collectRefs(e)) {
      if (!ids.has(target)) {
        errors.push(`LINK    ${e.id}: ${field} -> "${target}" exists nowhere (needs an entry or a stub)`);
      }
    }
  }

  const stubs = entries.filter((x) => x.data.status === 'stub').map((x) => x.data.id);
  return { entries, errors, stubs };
}

// --- CLI ------------------------------------------------------------------

function parseArgs(argv) {
  const out = { quiet: false, json: false, help: false };
  for (const a of argv) {
    if (a === '--quiet' || a === '-q') out.quiet = true;
    else if (a === '--json') out.json = true;
    else if (a === '--help' || a === '-h') out.help = true;
    else {
      console.error(`validate: unknown arg: ${a}`);
      process.exit(2);
    }
  }
  return out;
}

const HELP = `Usage:
  node tooling/validate.mjs [options]

Options:
  --quiet, -q       only print on failure (silent on success)
  --json            machine-readable JSON report
  -h, --help        show this help

Exit codes:
  0  clean — schema + id + link integrity all pass
  1  one or more errors found
  2  bad CLI args
`;

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) { process.stdout.write(HELP); process.exit(0); }

  const { entries, errors, stubs } = validateCorpus();
  const full = entries.filter((x) => x.data.status !== 'stub').map((x) => x.data.id);

  if (args.json) {
    process.stdout.write(JSON.stringify({
      ok: errors.length === 0,
      entriesCount: entries.length,
      fullCount: full.length,
      stubsCount: stubs.length,
      stubs,
      errors,
    }, null, 2) + '\n');
    process.exit(errors.length === 0 ? 0 : 1);
  }

  if (errors.length === 0) {
    if (!args.quiet) {
      console.log(`codex validate — walked content/entries/**`);
      console.log(`  ${entries.length} entries (${full.length} full, ${stubs.length} stubs)\n`);
      if (stubs.length > 0) {
        console.log(`Stubs (coverage TODO):`);
        console.log(`  ${stubs.join(', ')}\n`);
      }
      console.log(`✓ All checks passed (schema, id-vs-filename, link integrity).`);
    }
    process.exit(0);
  } else {
    console.error(`codex validate — walked content/entries/**`);
    console.error(`  ${entries.length} entries (${full.length} full, ${stubs.length} stubs)`);
    console.error(``);
    console.error(`✗ FAILED — ${errors.length} error(s):`);
    for (const e of errors) console.error(`  - ${e}`);
    process.exit(1);
  }
}

// Run main() only when invoked as a script, not when imported as a module.
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
