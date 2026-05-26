#!/usr/bin/env node
// IN-SANDBOX WEB PREVIEW — a stand-in for the Astro build.
// Astro (web/) is the REAL web consumer, but its dependency tree exceeds the sandbox's
// 45s install limit. This small renderer reuses the SAME content/ and the SAME schema/
// to prove "SSOT -> cross-linked HTML, Persian intact, stubs marked". Output: build/preview/*.html
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, basename, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import matter from 'gray-matter';
import { marked } from 'marked';
import { entrySchema } from './schema/entrySchema.mjs';

const ROOT = dirname(fileURLToPath(import.meta.url));
const ENTRIES_DIR = join(ROOT, 'content', 'entries');
const OUT = join(ROOT, 'build', 'preview');
const SECTION_ORDER = ['Story', 'History', 'Primary text', 'Game lens'];

const walk = (dir) => readdirSync(dir).flatMap((n) => {
  const p = join(dir, n);
  return statSync(p).isDirectory() ? walk(p) : (n.endsWith('.md') ? [p] : []);
});

function splitSections(body) {
  const buf = { _intro: [] };
  let cur = '_intro';
  for (const line of body.split('\n')) {
    const m = line.match(/^##\s+(.+?)\s*$/);
    if (m) { cur = m[1].trim(); buf[cur] = []; } else { (buf[cur] ||= []).push(line); }
  }
  const out = {};
  for (const [k, v] of Object.entries(buf)) { const t = v.join('\n').trim(); if (t) out[k] = t; }
  return out;
}

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// load + validate against the shared schema (same gate the game export uses)
const entries = [];
for (const f of walk(ENTRIES_DIR)) {
  const { data, content } = matter(readFileSync(f, 'utf8'));
  const p = entrySchema.safeParse(data);
  if (!p.success) { console.error('SCHEMA', relative(ROOT, f), p.error.issues.map((i) => i.path.join('.') + ' ' + i.message).join('; ')); process.exit(1); }
  entries.push({ ...p.data, sections: splitSections(content) });
}
const byId = Object.fromEntries(entries.map((e) => [e.id, e]));

const anchor = (id, label) => {
  const t = byId[id]; const stub = !t || t.status === 'stub';
  return `<a href="./${id}.html"${stub ? ' class="stub"' : ''}>${esc(label || (t ? t.title : id))}</a>`;
};
// [[id]] / [[id|label]] -> anchor (marked passes inline HTML through)
const wiki = (md) => md.replace(/\[\[([^\]|]+?)(?:\|([^\]]+?))?\]\]/g, (_, id, label) => anchor(id.trim(), label && label.trim()));

const CSS = `
  body{font-family:system-ui,-apple-system,sans-serif;max-width:760px;margin:0 auto;padding:2rem 1.25rem;line-height:1.65;color:#23201c;background:#fbf8f1}
  header{margin-bottom:1.25rem}a{color:#7a1f2b;text-decoration:none}a:hover{text-decoration:underline}
  a.stub{color:#a99;font-style:italic}h1{margin-bottom:.1rem}h2{color:#5c1620;border-bottom:1px solid #e7dfca;padding-bottom:.2rem;margin-top:1.8rem}
  .fa{font-size:1.2em;color:#5c1620}.summary{font-style:italic;color:#555;margin-top:.2rem}
  .tags{margin:.4rem 0 1rem}.tag{background:#efe7d2;border-radius:4px;padding:.12rem .5rem;font-size:.78em;margin-inline-end:.35rem;color:#6b5a2e}
  .stubtag{color:#a99;font-style:italic}blockquote{border-inline-start:3px solid #c9a227;margin-inline:0;padding:.3rem 1rem;background:#fdfbf4;color:#33302a}
  nav.sidebar{font-size:.92em;border-top:1px solid #e7dfca;margin-top:2.2rem;padding-top:1rem;color:#444}
  nav.sidebar strong{color:#5c1620}
`;

const page = (title, bodyHtml) =>
`<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} — Shahnameh Codex (preview)</title><style>${CSS}</style></head>
<body><header><a href="./index.html">← Shahnameh Codex</a> <span style="color:#bbb">· in-sandbox preview (Astro is the real renderer)</span></header>
${bodyHtml}</body></html>`;

function renderEntry(e) {
  const d = e;
  const faTitle = d.title_fa ? ` <span class="fa" dir="rtl">${esc(d.title_fa)}</span>` : '';
  const tags = [d.age, d.register, d.type].filter(Boolean).map((t) => `<span class="tag">${esc(t)}</span>`).join('') +
    (d.status === 'stub' ? `<span class="stubtag">stub — not yet written</span>` : '');
  const orderedKeys = [...SECTION_ORDER.filter((k) => d.sections[k]), ...Object.keys(d.sections).filter((k) => !SECTION_ORDER.includes(k) && k !== '_intro')];
  const sections = orderedKeys.map((k) => `<h2>${esc(k)}</h2>\n${marked.parse(wiki(d.sections[k]))}`).join('\n');

  const rel = Object.entries(d.relationships || {});
  const relHtml = rel.length ? `<div><strong>Relationships</strong><ul>` +
    rel.map(([k, ids]) => `<li>${esc(k)}: ${ids.map((id) => anchor(id)).join(', ')}</li>`).join('') + `</ul></div>` : '';
  const relatedHtml = (d.related || []).length ? `<p><strong>See also:</strong> ${d.related.map((id) => anchor(id)).join(', ')}</p>` : '';
  const back = entries.filter((x) => x.id !== d.id && (
    Object.values(x.relationships || {}).flat().includes(d.id) || (x.related || []).includes(d.id) || x.origin === d.id || x.seat === d.id));
  const backHtml = back.length ? `<p><strong>Mentioned in:</strong> ${back.map((x) => anchor(x.id)).join(', ')}</p>` : '';
  const srcHtml = (d.sources || []).length ? `<p><strong>Sources:</strong> ${d.sources.map(esc).join(', ')}</p>` : '';

  return page(d.title, `<h1>${esc(d.title)}${faTitle}</h1>
<div class="summary">${esc(d.summary)}</div>
<div class="tags">${tags}</div>
${sections}
<nav class="sidebar">${relHtml}${relatedHtml}${backHtml}${srcHtml}</nav>`);
}

mkdirSync(OUT, { recursive: true });
for (const e of entries) writeFileSync(join(OUT, `${e.id}.html`), renderEntry(e), 'utf8');

const list = [...entries].sort((a, b) => a.title.localeCompare(b.title)).map((e) =>
  `<li>${anchor(e.id)}${e.title_fa ? ` <span class="fa" dir="rtl">${esc(e.title_fa)}</span>` : ''}${e.status === 'stub' ? ' <span class="stubtag">· stub</span>' : ''}<br><small>${esc(e.summary)}</small></li>`).join('\n');
writeFileSync(join(OUT, 'index.html'), page('Index', `<h1>Shahnameh Codex</h1><p>${entries.length} entries.</p><ul>${list}</ul>`), 'utf8');

console.log(`✓ Rendered ${entries.length} preview pages -> ${relative(ROOT, OUT)}/`);
