# Codex — Build Log

Append a dated entry per working session (newest at top). Code sessions and the design chat both log here.

---

## 2026-05-24 — Phase 0: tracer bullet (design chat / Cowork)

**Shipped:**
- Project scaffolded under `codex/` (sibling to `game/`). Design docs: `ARCHITECTURE.md`, `CONVENTIONS.md`, `STATUS.md`, plus this log and `QUESTIONS_FOR_DESIGN.md`.
- **Schema:** `schema/entrySchema.mjs` (zod) — the single contract for both consumers; written zod v3/v4 compatible (two-arg `z.record`).
- **SSOT content:** `content/entries/` with two full entries (`farr`, `rostam`) and 7 stubs (afrasiyab, esfandiyar, jamshid, rakhsh, simorgh, zabolestan, zal); `content/sources.yaml`.
- **Game export:** `export/export.mjs → build/codex.json` — 9 entries, schema-validated, stub-aware referential integrity, Persian intact (UTF-8). Verified.
- **Web (real consumer):** `web/` Astro project scaffolded — Content Layer `glob` loader, shared schema (`id` omitted), `[[wiki-link]]` remark plugin, `/entry/[id]` + index pages.
- **Web proof (stand-in):** `preview.mjs → build/preview/*.html` — reuses the same content+schema; confirmed RTL Persian render, all cross-links resolve, stub links styled.

**Not done / next session state:**
- The **real Astro build was NOT run** (its install exceeds the cloud sandbox's 45s limit). Confirm locally: `cd codex/web && rm -rf node_modules && npm install && npm run build`.
- A partial, permission-locked `web/node_modules` may remain from the interrupted sandbox install (gitignored) — `rm -rf` it locally before installing.
- `farr.md` `primary_text` is a TODO (fetch the Jamshid farr-departure passage from Ganjoor).

**Open questions:** see `QUESTIONS_FOR_DESIGN.md` (naming calls + farr verse).
