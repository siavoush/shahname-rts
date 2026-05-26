#!/usr/bin/env node
// fetch-verse.mjs — Ganjoor verse-fetch CLI. The CRITICAL LAW tool.
//
// Persian verse in the codex comes ONLY from Ganjoor via this fetcher, never
// from a model's weights. Use it to pull verified couplets with provenance
// before pasting any `fa:` text into a `primary_text` block.
//
// Usage:
//   node tooling/fetch-verse.mjs <ganjoor-url|path>            # all couplets
//   node tooling/fetch-verse.mjs <url> --beyt 30               # single couplet (1-indexed)
//   node tooling/fetch-verse.mjs <url> --beyt 28-32            # range (inclusive)
//   node tooling/fetch-verse.mjs <url> --grep "زیب و فر"        # couplets containing text
//   node tooling/fetch-verse.mjs <url> --out couplets.json     # write to file
//
// Output JSON shape (paste-ready for an entry's primary_text after a human
// adds transliteration and translation):
//   {
//     "ref": "ganjoor",
//     "url": "https://ganjoor.net/ferdousi/shahname/esfandyar/sh26",
//     "loc_fa": "فردوسی » شاهنامه » داستان رستم و اسفندیار » بخش ۲۶",
//     "poem_id": 1600,
//     "couplets_total": 84,
//     "couplets": [
//       { "beyt": 1,  "fa": "ببودند هر دو بران رای مند / سپهبد برآمد به بالا بلند" },
//       { "beyt": 30, "fa": "بران خستگیها بمالید پر / هم اندر زمان گشت با زیب و فر" }
//     ]
//   }
//
// The API endpoint (api.ganjoor.net/api/ganjoor/page) returns the verses as
// a structured array with coupletIndex + versePosition, which is far cleaner
// than HTML-scraping the public page (the HTML mixes verse, AI paraphrase,
// and comment threads). API chosen for this reason.

import { writeFileSync } from 'node:fs';

const API_BASE = 'https://api.ganjoor.net/api/ganjoor/page';
const SITE_BASE = 'https://ganjoor.net';

// --- arg parsing -----------------------------------------------------------

function parseArgs(argv) {
  const args = { url: null, beyt: null, grep: null, out: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--beyt') args.beyt = argv[++i];
    else if (a === '--grep') args.grep = argv[++i];
    else if (a === '--out') args.out = argv[++i];
    else if (a === '--help' || a === '-h') args.help = true;
    else if (a.startsWith('--')) die(`unknown flag: ${a}`);
    else if (!args.url) args.url = a;
    else die(`unexpected positional arg: ${a}`);
  }
  return args;
}

function die(msg) {
  console.error(`fetch-verse: ${msg}`);
  process.exit(2);
}

// --- URL normalization -----------------------------------------------------

// Accepts:
//   https://ganjoor.net/ferdousi/shahname/esfandyar/sh26
//   /ferdousi/shahname/esfandyar/sh26
//   ferdousi/shahname/esfandyar/sh26
// Returns the canonical path (e.g. /ferdousi/shahname/esfandyar/sh26).
function normalizePath(input) {
  if (!input) die('missing Ganjoor URL or path');
  let p = input.trim();
  if (p.startsWith('http://') || p.startsWith('https://')) {
    const u = new URL(p);
    if (!u.hostname.endsWith('ganjoor.net')) {
      die(`URL host must be ganjoor.net, got: ${u.hostname}`);
    }
    p = u.pathname;
  }
  if (!p.startsWith('/')) p = '/' + p;
  // strip trailing slash (the API rejects /foo/ when it expects /foo)
  if (p.length > 1 && p.endsWith('/')) p = p.slice(0, -1);
  return p;
}

// --- beyt-range parsing ----------------------------------------------------

// "30" -> [30, 30]; "28-32" -> [28, 32]
function parseBeytRange(spec) {
  const m = String(spec).match(/^(\d+)(?:-(\d+))?$/);
  if (!m) die(`invalid --beyt value: ${spec} (expected N or M-N)`);
  const lo = parseInt(m[1], 10);
  const hi = m[2] ? parseInt(m[2], 10) : lo;
  if (lo < 1 || hi < lo) die(`invalid --beyt range: ${spec}`);
  return [lo, hi];
}

// --- API fetch -------------------------------------------------------------

async function fetchPoem(path) {
  const url = `${API_BASE}?url=${encodeURIComponent(path)}`;
  let res;
  try { res = await fetch(url, { headers: { accept: 'application/json' } }); }
  catch (e) { die(`network error fetching ${url}: ${e.message}`); }
  if (!res.ok) die(`API returned HTTP ${res.status} for ${path}`);
  let data;
  try { data = await res.json(); }
  catch (e) { die(`API returned non-JSON for ${path}: ${e.message}`); }
  if (!data || !data.poem || !Array.isArray(data.poem.verses)) {
    die(`API response missing poem.verses for ${path}`);
  }
  return data;
}

// --- couplet assembly ------------------------------------------------------

// Group verses by coupletIndex, join mesras with " / " in versePosition order.
// Persian poetry mesras are conventionally separated by " / " in single-line
// quotation form (the form already used in the codex: see rostam.md).
function buildCouplets(verses) {
  const groups = new Map();
  for (const v of verses) {
    if (!groups.has(v.coupletIndex)) groups.set(v.coupletIndex, []);
    groups.get(v.coupletIndex).push(v);
  }
  const out = [];
  for (const [idx, mesras] of [...groups.entries()].sort((a, b) => a[0] - b[0])) {
    mesras.sort((a, b) => a.versePosition - b.versePosition);
    const text = mesras.map(m => m.text).join(' / ');
    out.push({ beyt: idx + 1, fa: text });
  }
  return out;
}

// --- filters ---------------------------------------------------------------

function applyFilters(couplets, args) {
  let out = couplets;
  if (args.beyt) {
    const [lo, hi] = parseBeytRange(args.beyt);
    out = out.filter(c => c.beyt >= lo && c.beyt <= hi);
    if (out.length === 0) die(`no couplets in beyt range ${args.beyt} (poem has ${couplets.length})`);
  }
  if (args.grep) {
    out = out.filter(c => c.fa.includes(args.grep));
    if (out.length === 0) die(`no couplets matched --grep "${args.grep}"`);
  }
  return out;
}

// --- main ------------------------------------------------------------------

const HELP = `Usage:
  node tooling/fetch-verse.mjs <ganjoor-url|path> [options]

Options:
  --beyt N          single couplet, 1-indexed
  --beyt M-N        couplet range (inclusive)
  --grep TEXT       only couplets containing TEXT (Persian substring)
  --out PATH        write to file instead of stdout
  -h, --help        show this help

Examples:
  node tooling/fetch-verse.mjs https://ganjoor.net/ferdousi/shahname/esfandyar/sh26
  node tooling/fetch-verse.mjs /ferdousi/shahname/esfandyar/sh26 --beyt 30
  node tooling/fetch-verse.mjs /ferdousi/shahname/esfandyar/sh26 --grep "زیب و فر"
`;

const args = parseArgs(process.argv.slice(2));
if (args.help) { console.log(HELP); process.exit(0); }

const path = normalizePath(args.url);
const data = await fetchPoem(path);
const allCouplets = buildCouplets(data.poem.verses);
const filtered = applyFilters(allCouplets, args);

const result = {
  ref: 'ganjoor',
  url: `${SITE_BASE}${data.poem.fullUrl || path}`,
  loc_fa: data.poem.fullTitle,
  poem_id: data.poem.id,
  couplets_total: allCouplets.length,
  couplets: filtered,
};

const json = JSON.stringify(result, null, 2);
if (args.out) {
  writeFileSync(args.out, json + '\n', 'utf8');
  console.error(`wrote ${filtered.length}/${allCouplets.length} couplets -> ${args.out}`);
} else {
  process.stdout.write(json + '\n');
}
