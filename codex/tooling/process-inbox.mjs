#!/usr/bin/env node
// process-inbox.mjs — autonomous FETCH-handoff assembler.
//
// Cowork writes entry drafts in FETCH-handoff form and drops them in the inbox.
// This processes them: fetches the canonical Persian verse on THIS side (raw
// API bytes via fetch-verse.mjs — never a summarizer model), assembles the
// final entry, validates the corpus, and opens a PR. Siavoush is not in the
// assembly loop; the PR merge stays the human gate.
//
// THE CRITICAL LAW is enforced structurally here: the ONLY Persian verse that
// can land is what fetch-verse.mjs returns. The handoff draft NEVER carries
// verse bytes — only FETCH(<url> beyt <N>) placeholders. After assembly, every
// fetched verse is byte-verified to appear in the written file, and every OTHER
// Persian string in the file is audited against CONVENTIONS.md. Any failure
// halts that entry (→ errors/) — the pipeline never fabricates or ships
// unverifiable Persian.
//
// Inbox layout (default ~/dev/shahnameh_rts/handoff, override with CODEX_INBOX):
//   handoff/*.md            — drafts to process
//   handoff/processed/      — successfully landed (PR opened)
//   handoff/errors/         — failed; each gets a sibling <id>.error.log
//
// Usage:
//   node tooling/process-inbox.mjs              # process all drafts; commit + push + PR
//   node tooling/process-inbox.mjs --dry-run    # assemble + validate only; no git, no move, no PR
//   node tooling/process-inbox.mjs --help
//
// A single run processes every *.md currently in the inbox. To poll on a
// schedule, wrap this in cron or the /loop skill — it is intentionally a
// one-shot, not a daemon (simpler, testable, composes with external scheduling).

import { readFileSync, writeFileSync, readdirSync, mkdirSync, rmSync, renameSync, existsSync, statSync } from 'node:fs';
import { join, dirname, basename, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { homedir } from 'node:os';
import matter from 'gray-matter';
import { entrySchema } from '../schema/entrySchema.mjs';

const SELF_DIR = dirname(fileURLToPath(import.meta.url));
const CODEX_ROOT = join(SELF_DIR, '..');               // codex/
const WORKTREE_ROOT = join(CODEX_ROOT, '..');          // git ops run here
const ENTRIES_DIR = join(CODEX_ROOT, 'content', 'entries');
const FETCH_TOOL = join(SELF_DIR, 'fetch-verse.mjs');
const CONVENTIONS = join(CODEX_ROOT, 'CONVENTIONS.md');
const INBOX = process.env.CODEX_INBOX || join(homedir(), 'dev', 'shahnameh_rts', 'handoff');
const PROCESSED = join(INBOX, 'processed');
const ERRORS = join(INBOX, 'errors');

// schema type -> content/entries subdirectory (explicit; no guessed pluralization)
const TYPE_DIR = {
  person: 'people', place: 'places', event: 'events', concept: 'concepts',
  dynasty: 'dynasties', creature: 'creatures', artifact: 'artifacts',
  passage: 'passages', faction: 'factions', unit: 'units',
  building: 'buildings', mechanic: 'mechanics',
};

const FETCH_RE = /^FETCH\(\s*(\S+)\s+beyt\s+(\d+(?:-\d+)?)\s*\)$/;
// Arabic-script blocks + the ZWNJ/ZWJ joiners (U+200C/200D) that Persian verse uses.
const ARABIC_CHARS = '؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿‌‍';
const hasPersian = (s) => new RegExp(`[${ARABIC_CHARS}]`).test(s);
const persianRuns = (s) => s.match(new RegExp(`[${ARABIC_CHARS}]+`, 'g')) || [];

const log = (msg) => console.log(`[process-inbox] ${msg}`);
const warn = (msg) => console.warn(`[process-inbox] WARN ${msg}`);

class EntryError extends Error {}

// --- shell helpers ---------------------------------------------------------

function git(args, opts = {}) {
  return execFileSync('git', args, { cwd: WORKTREE_ROOT, encoding: 'utf8', ...opts });
}
function npmInCodex(script) {
  return execFileSync('npm', ['run', script], { cwd: CODEX_ROOT, encoding: 'utf8' });
}
function nodeInCodex(args) {
  return execFileSync('node', args, { cwd: CODEX_ROOT, encoding: 'utf8' });
}

// --- verse fetch (the only verse source) -----------------------------------

// Returns the canonical fa string for a FETCH(url beyt N|M-N).
// Single beyt -> one couplet "<mesra_a> / <mesra_b>".
// Range -> couplets joined with " / " (flat hemistich sequence).
function fetchVerse(url, beytSpec) {
  let out;
  try {
    out = nodeInCodex([FETCH_TOOL, url, '--beyt', beytSpec]);
  } catch (e) {
    const detail = (e.stderr || e.stdout || e.message || '').toString().trim();
    throw new EntryError(`fetch-verse failed for ${url} beyt ${beytSpec}: ${detail}`);
  }
  let data;
  try { data = JSON.parse(out); } catch { throw new EntryError(`fetch-verse returned non-JSON for ${url} beyt ${beytSpec}`); }
  if (!data.couplets || data.couplets.length === 0) {
    throw new EntryError(`fetch-verse returned no couplets for ${url} beyt ${beytSpec}`);
  }
  return data.couplets.map((c) => c.fa).join(' / ');
}

// --- assembly --------------------------------------------------------------

// Mutates `data` in place: replaces FETCH placeholders with fetched verse +
// source block. Returns the list of fetched fa strings (for byte-verify).
function resolveFetches(data) {
  const fetched = [];
  const verses = Array.isArray(data.primary_text) ? data.primary_text : [];
  for (const item of verses) {
    if (typeof item.fa !== 'string') continue;
    const m = item.fa.match(FETCH_RE);
    if (!m) {
      // A literal Persian fa in a handoff draft means verse bypassed the tool — forbidden.
      if (hasPersian(item.fa)) {
        throw new EntryError(`primary_text carries literal Persian, not a FETCH() placeholder: "${item.fa.slice(0, 40)}…". Verse must be fetched, never pasted.`);
      }
      continue;
    }
    const [, url, beyt] = m;
    const fa = fetchVerse(url, beyt);
    const loc = item.loc;
    item.fa = fa;
    item.source = loc ? { ref: 'ganjoor', loc, url } : { ref: 'ganjoor', url };
    delete item.loc;
    fetched.push(fa);
    log(`  fetched ${url} beyt ${beyt} (${fa.length} chars)`);
  }
  return fetched;
}

// Every Persian run in the assembled file must be traceable: either it IS one
// of the fetched verses, or it appears verbatim in CONVENTIONS.md. Anything
// else is untraceable Persian and halts the entry.
function auditPersian(assembledText, fetchedFas) {
  const conventions = readFileSync(CONVENTIONS, 'utf8');
  // Mask out fetched verses so we only audit non-verse Persian (names/concepts).
  let masked = assembledText;
  for (const fa of fetchedFas) masked = masked.split(fa).join('');
  const runs = new Set(persianRuns(masked));
  const untraceable = [];
  for (const run of runs) {
    const t = run.trim();
    if (!t) continue;
    if (!conventions.includes(t)) untraceable.push(t);
  }
  if (untraceable.length) {
    throw new EntryError(
      `untraceable Persian (not a fetched verse, not in CONVENTIONS.md): ${untraceable.map((s) => `"${s}"`).join(', ')}`
    );
  }
}

// --- corpus checks ---------------------------------------------------------

function runChecks() {
  log('  validate…'); npmInCodex('validate');
  log('  export…');   npmInCodex('export');
  log('  preview…');  nodeInCodex([join(CODEX_ROOT, 'preview.mjs')]);
}

// --- PR body (BUILD_LOG inlined) -------------------------------------------

function prBody(data, fetched, relPath) {
  const date = new Date().toISOString().slice(0, 10);
  const verseLines = (data.primary_text || [])
    .filter((v) => v.source && v.source.url)
    .map((v) => `- \`${v.source.loc || v.source.url}\` — fetched via fetch-verse.mjs, byte-verified in the committed file`)
    .join('\n') || '- (no verse in this entry)';
  return `## Codex entry: ${data.title} (\`${data.id}\`)

Assembled by \`tooling/process-inbox.mjs\` from a FETCH-handoff draft. Verse was fetched on the codex side from Ganjoor's raw API (no summarizer model in the loop), never carried as bytes through the handoff.

**Verse provenance (CRITICAL LAW):**
${verseLines}

**Pipeline checks:** validate ✓ · export ✓ · preview ✓ · byte-verify ✓ · Persian-surface audit ✓

**BUILD_LOG entry (inlined):**

\`\`\`
## ${date} — Codex entry \`${data.id}\` (${data.type}, automated assembly)
Assembled from FETCH-handoff draft via process-inbox.mjs. ${fetched.length} verse couplet(s) fetched from Ganjoor with provenance; byte-verified against the committed file. Cross-links validated (stub-aware). File: ${relPath}.
\`\`\`

🤖 Assembled by process-inbox.mjs`;
}

// --- per-entry processing --------------------------------------------------

function processDraft(draftPath, { dryRun, startBranch }) {
  const draftName = basename(draftPath);
  log(`processing ${draftName}`);
  const raw = readFileSync(draftPath, 'utf8');
  const parsed = matter(raw);
  const data = parsed.data;

  if (!data.id) throw new EntryError('draft frontmatter missing `id`');
  if (!data.type || !TYPE_DIR[data.type]) throw new EntryError(`draft has unknown/missing type: ${data.type}`);
  const id = data.id;

  // 1. Resolve FETCH placeholders -> canonical verse + source.
  const fetched = resolveFetches(data);

  // 2. Re-serialize. matter.stringify writes Persian as literal UTF-8 (verified).
  const assembled = matter.stringify(parsed.content, data);

  // 3. Schema-validate the assembled frontmatter before it touches the corpus.
  const check = entrySchema.safeParse(data);
  if (!check.success) {
    throw new EntryError(`assembled frontmatter fails schema: ${check.error.issues.map((i) => `${i.path.join('.')} — ${i.message}`).join('; ')}`);
  }

  // 4. Byte-verify: every fetched verse must appear verbatim in the assembled text.
  for (const fa of fetched) {
    if (!assembled.includes(fa)) throw new EntryError(`byte-verify FAILED: fetched verse not found verbatim in assembled file: "${fa.slice(0, 40)}…"`);
  }

  // 5. Persian-surface audit: non-verse Persian must trace to CONVENTIONS.md.
  auditPersian(assembled, fetched);

  const outRel = join('codex', 'content', 'entries', TYPE_DIR[data.type], `${id}.md`);
  const outAbs = join(ENTRIES_DIR, TYPE_DIR[data.type], `${id}.md`);

  if (dryRun) {
    // Write, run corpus checks, then remove — leave the tree as we found it.
    mkdirSync(dirname(outAbs), { recursive: true });
    const preExisted = existsSync(outAbs);
    const backup = preExisted ? readFileSync(outAbs, 'utf8') : null;
    writeFileSync(outAbs, assembled, 'utf8');
    try {
      runChecks();
      log(`  DRY-RUN ok: ${id} (${fetched.length} verse(s)) → would land at ${outRel}`);
      for (const fa of fetched) log(`    verse: ${fa}`);
    } finally {
      if (backup !== null) writeFileSync(outAbs, backup, 'utf8');
      else rmSync(outAbs, { force: true });
    }
    return { id, branch: null, pr: null, dryRun: true };
  }

  // --- real run: branch off origin/main, write, check, commit, push, PR ---
  const branch = `feat/codex-${id}`;
  git(['fetch', 'origin', 'main']);
  // Fresh branch off latest main. If it already exists, that's an error worth surfacing.
  try { git(['checkout', '-b', branch, 'origin/main']); }
  catch (e) { throw new EntryError(`could not create branch ${branch} (already exists?): ${(e.stderr || e.message).toString().trim()}`); }

  try {
    mkdirSync(dirname(outAbs), { recursive: true });
    writeFileSync(outAbs, assembled, 'utf8');
    runChecks();
    // Re-verify on disk (checks ran against the written file; confirm bytes survived).
    const onDisk = readFileSync(outAbs, 'utf8');
    for (const fa of fetched) {
      if (!onDisk.includes(fa)) throw new EntryError(`on-disk byte-verify FAILED for "${fa.slice(0, 40)}…"`);
    }
    git(['add', '--', outRel]);
    git(['commit', '-m', `codex(${id}): assemble entry from FETCH-handoff draft\n\n${fetched.length} verse couplet(s) fetched from Ganjoor via fetch-verse.mjs (raw API, no model in the loop) and byte-verified. Cross-links validated stub-aware. Assembled by process-inbox.mjs.`, '--', outRel]);
    git(['push', '-u', 'origin', branch]);
    const pr = execFileSync('gh', ['pr', 'create', '--base', 'main', '--head', branch, '--title', `codex(${id}): ${data.title}`, '--body', prBody(data, fetched, outRel)], { cwd: WORKTREE_ROOT, encoding: 'utf8' }).trim();
    log(`  PR opened: ${pr}`);
    git(['checkout', startBranch]);
    return { id, branch, pr };
  } catch (e) {
    // Roll back the branch so a failure leaves no half-built state.
    try { git(['checkout', startBranch]); } catch {}
    try { git(['branch', '-D', branch]); } catch {}
    throw e instanceof EntryError ? e : new EntryError((e.stderr || e.message || String(e)).toString().trim());
  }
}

// --- main ------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    console.log('Usage: node tooling/process-inbox.mjs [--dry-run]');
    process.exit(0);
  }
  const dryRun = args.includes('--dry-run');

  mkdirSync(INBOX, { recursive: true });
  mkdirSync(PROCESSED, { recursive: true });
  mkdirSync(ERRORS, { recursive: true });

  const drafts = readdirSync(INBOX)
    .filter((f) => f.endsWith('.md'))
    .map((f) => join(INBOX, f))
    .filter((p) => statSync(p).isFile());

  if (drafts.length === 0) { log(`inbox empty (${INBOX}) — nothing to do`); return; }
  log(`${dryRun ? '[DRY-RUN] ' : ''}found ${drafts.length} draft(s) in ${INBOX}`);

  let startBranch = null;
  if (!dryRun) {
    // Real runs mutate branches — require a clean tracked tree to start.
    const dirty = git(['status', '--porcelain', '--untracked-files=no']).trim();
    if (dirty) { console.error(`[process-inbox] ABORT: worktree has uncommitted tracked changes:\n${dirty}`); process.exit(1); }
    startBranch = git(['rev-parse', '--abbrev-ref', 'HEAD']).trim();
    log(`start branch: ${startBranch}`);
  }

  const results = { ok: [], failed: [] };
  for (const draftPath of drafts) {
    const id = basename(draftPath, '.md');
    try {
      const r = processDraft(draftPath, { dryRun, startBranch });
      if (!dryRun) renameSync(draftPath, join(PROCESSED, basename(draftPath)));
      results.ok.push(r.id || id);
    } catch (e) {
      const detail = e instanceof EntryError ? e.message : (e.stack || String(e));
      console.error(`[process-inbox] FAILED ${basename(draftPath)}: ${detail}`);
      if (!dryRun) {
        writeFileSync(join(ERRORS, `${id}.error.log`), `${new Date().toISOString()}\n${detail}\n`, 'utf8');
        try { renameSync(draftPath, join(ERRORS, basename(draftPath))); } catch {}
      }
      results.failed.push(id);
    }
  }

  log(`done. ok: [${results.ok.join(', ') || 'none'}] · failed: [${results.failed.join(', ') || 'none'}]`);
  if (results.failed.length) process.exit(1);
}

main();
