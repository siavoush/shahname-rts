# Codex — Status

## Phase 0 — Tracer bullet ✅ (2026-05-24)

The pipeline is proven end-to-end: **one source of truth (`content/` + `schema/`) feeds both consumers.**

### What's proven
- **Game export** (`export/export.mjs` → `build/codex.json`): 9 entries, schema-validated, referential integrity enforced (stub-aware), **Persian preserved as UTF-8** (`رستم`, `فرّ`, the verbatim Esfandiyar/Simorgh couplet). This is the game bridge — Godot reads this JSON.
- **Web** (the real consumer is **Astro**, in `web/`): scaffolded with the Content Layer `glob` loader, the shared schema (`id` omitted, Astro derives it from filename), a `[[wiki-link]]` remark plugin, an `/entry/[id]` page (4 sections + relationships + backlinks + sources) and an index.
- **In-sandbox web preview** (`preview.mjs` → `build/preview/*.html`): a stand-in that reuses the *same* content + schema to render cross-linked HTML, proving `SSOT → web` here. Confirmed: RTL Persian renders, all 8 cross-links resolve, 4 stub links are styled as "not yet written."

### Content so far
- **Full entries:** `farr`, `rostam` (the two that exercise the whole schema surface).
- **Stubs (Phase 1 TODO):** afrasiyab, esfandiyar, jamshid, rakhsh, simorgh, zabolestan, zal — they exist so cross-links resolve, and demonstrate the stub mechanism.

## How to run locally (on your Mac)

```bash
# 1. Game export (fast, ~1s):
cd codex
npm install            # zod + gray-matter + marked
npm run export         # -> build/codex.json

# 2. In-sandbox-style preview (no Astro needed):
node preview.mjs       # -> open build/preview/index.html

# 3. The REAL web build (Astro):
cd codex/web
rm -rf node_modules    # clear any partial install (see note below)
npm install            # heavy — fine locally, too big for the cloud sandbox's 45s limit
npm run dev            # -> http://localhost:4321   (or: npm run build -> web/dist)
```

## Known notes / Phase-1 follow-ups
- **Astro build was NOT run in the cloud sandbox** — its dependency tree exceeds the 45s install ceiling. The Astro project files are committed and correct; confirm the first real build locally with the commands above. The `preview.mjs` output is the in-sandbox stand-in.
- **Partial `web/node_modules`** may remain from the interrupted sandbox install and is permission-locked there (it's gitignored). On your Mac: `rm -rf codex/web/node_modules && npm install`.
- **zod v3 vs v4:** the exporter resolves zod v3; Astro pulls zod v4. The shared schema is written compatibly (two-arg `z.record(key, value)`). Verify at first local Astro build; if anything else trips, that's the place to look.
- **`farr.md` primary text** is a TODO — fetch the canonical Jamshid farr-departure passage from Ganjoor (see `CONVENTIONS.md §5`).

## Suggested next (Phase 1)
1. Confirm the real Astro build locally.
2. Author the **Jamshid → Zahhak → Kaveh → Fereydun → division-of-the-world** cluster (seeds the Iran–Turan war and the Farr concept).
3. Add **Pagefind** search; then the **timeline** view (the cheapest, most pedagogically powerful index).
