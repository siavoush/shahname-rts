# Codex — Build Log

Append a dated entry per working session (newest at top). Code sessions and the design chat both log here.

---

## 2026-05-26 — Phase 1: Work Order 01 (Claude Code, infra/codex-phase-1)

First code-session run on the codex side. Brought Phase 0 into git (it had only been shipped to disk by the design chat) and landed all four lore-free items from `WORK_ORDERS/01_infra_kickoff.md`. Five commits on `infra/codex-phase-1` off `main`:

**Shipped:**
- **Phase 0 initial import** — the 31-file tree authored 2026-05-24 (charter docs, schema, SSOT, exporter, preview, Astro scaffold) is now tracked in git. Boundary contract agreed with the game-side session: codex commits touch only `codex/**`, branch off `main`, never wave branches.
- **WO 01/1 — real Astro build clean.** Diagnosed and fixed an id-derivation mismatch between the two consumers: exporter uses filename basename (`rostam`), but Astro's `glob` loader was deriving `people/rostam` from the path-relative-to-base, breaking the single-segment `[id].astro` route. One-line fix: `generateId: ({entry}) => basename(entry, '.md')` in `web/src/content.config.ts`. Both consumers now agree on the basename convention. 10 pages (9 entries + index) build clean; cross-links + backlinks + RTL Persian all render.
- **WO 01/2 — Pagefind search.** Post-build index step (`pagefind --site dist`) wired into the build chain; Default UI search box on the index page. `aka` values rendered as `class="sr-only"` for indexability without disturbing visual layout (visible-aka becomes a content/design call later). Index: 10 pages, 432 words, WASM modules for `en` + `unknown` (the latter covers Persian tokens). All four acceptance terms — Rostam / Rustam / Tahamtan / رستم — verified present in the indexed body HTML.
- **WO 01/3 — Ganjoor verse-fetch CLI** (`tooling/fetch-verse.mjs`). **The mechanical guard on the CRITICAL LAW.** Uses the Ganjoor JSON API (`api.ganjoor.net/api/ganjoor/page`) over HTML scrape — the API gives a structured `verses[]` array indexed by coupletIndex + versePosition, avoiding the page's mix of verse + AI paraphrase + comment threads. Zero deps (native fetch). Flags: `--beyt N`, `--beyt M-N`, `--grep <fa-substring>`, `--out PATH`. Acceptance verified against the URL in the work order: couplet 30 returns `بران خستگیها بمالید پر / هم اندر زمان گشت با زیب و فر` — byte-identical to the line already in `rostam.md`.
- **WO 01/4 — link-integrity validator** (`tooling/validate.mjs`). Pure `validateCorpus()` function + CLI wrapper. `export.mjs` refactored to import it — validation logic now has one home; the exporter owns only section-splitting + JSON emission. Added `geo.region` to the ref walk (closes a gap in the previous exporter logic). CLI exits non-zero on any error; supports `--quiet` and `--json`. Stress test verified: injecting a `relationships.killer: [doomslayer]` link makes both `npm run validate` and `npm run export` exit 1 with a clear message; reverting returns both to green.

**Full pipeline verified (end-of-session, codex/CLAUDE.md §coordination):**
- `npm run validate` → ✓ exit 0
- `npm run export` → ✓ 9 entries to `build/codex.json`
- `node preview.mjs` → ✓ 9 preview pages to `build/preview/`
- `cd web && npm run build` (Astro + Pagefind) → ✓ 10 pages, RTL Persian renders, all cross-links + backlinks resolve

**Process note — worktree migration mid-session:**
The first three codex commits landed from the same primary working tree the game-side session uses (`/Users/siavoush/dev/shahnameh_rts/ShahnamehRTS/`). After my `git checkout -b infra/codex-phase-1`, the game session's HEAD silently switched onto my branch — caught by the game session at commit time. They recovered cleanly (stash → checkout → pop → commit). I migrated to a sibling worktree at `/Users/siavoush/dev/shahnameh_rts/ShahnamehRTS-codex/` for the remainder of the session. **Going forward, codex sessions MUST use `git worktree add` from the start.** The boundary contract is being amended accordingly.

**Not done / open:**
- PR for `infra/codex-phase-1` not yet opened (pending user OK to push).
- `farr.md` `primary_text` still TODO (verse selection is a design-chat call; `tooling/fetch-verse.mjs` is the mechanical fetcher once the passage is chosen).
- `web/package-lock.json` is now committed (Astro + Pagefind deps pinned).

**Open questions:** none added this session. The five `QUESTIONS_FOR_DESIGN.md` entries from Phase 0 remain open (Siavash/Siavoush, Simorgh/Simurgh, Haft Khan/Khwan, Sekandar's `register`, `farr.md` primary text).

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
