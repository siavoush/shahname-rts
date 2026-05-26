# Work Order 01 — Infra kickoff (lore-free)

**For:** a Claude Code session. **Prereq:** read `CLAUDE.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `STATUS.md` first.

**Why this is the first task:** it's pure machinery — no lore, no entry substance, no naming calls — so it can run in parallel while the design chat authors content. Each item below is independently shippable.

## Scope

### 1. Confirm the real Astro build
- `cd codex/web && rm -rf node_modules package-lock.json && npm install`.
- `npm run build` must produce `web/dist/` with working `/entry/rostam`, `/entry/farr`, and the index.
- Fix anything that trips — most likely the **zod v3 (exporter) vs zod v4 (Astro)** seam where `web/src/content.config.ts` imports `../../schema/entrySchema.mjs`. Keep the schema the single shared source; if a v4 incompatibility appears, fix it *in the shared schema* compatibly (don't fork it). Verify the `[[wiki-link]]` plugin resolves links and RTL Persian renders.
- Acceptance: `npm run build` is clean; the two entry pages + index render with cross-links, backlinks, and Persian.

### 2. Pagefind search
- Add Pagefind to the Astro build (post-build index step) with a search box on the index page.
- Index `title`, `title_fa`, `aka`, `summary`, and body text so "Rostam", "Rustam", and "رستم" all find Rostam.
- Acceptance: searching a transliteration variant and a Persian spelling both return the right entry.

### 3. Ganjoor verse-fetch tool (`tooling/fetch-verse.mjs`)
- A CLI that, given a Ganjoor poem URL (or section path), fetches the page and extracts the **clean verse couplets** (the text under the `بخش …` heading, *before* the `برگردان به زبان ساده` prose paraphrase and the comment threads), returning them with provenance (`url`, section, beyt numbers) as JSON ready to paste into an entry's `primary_text`.
- Prefer the Ganjoor JSON API (`api.ganjoor.net`) if it gives cleaner output than HTML scraping — evaluate and document which you used.
- This tool is what enforces the **Ganjoor-only-Persian law** — verse is always fetched, never recalled.
- Acceptance: running it on `https://ganjoor.net/ferdousi/shahname/esfandyar/sh26` returns the healing couplets (incl. the `…زیب و فر` line) verbatim with provenance.

### 4. Standalone link-integrity validator (`tooling/validate.mjs`)
- Walk `content/entries/**`, parse via the shared schema, and report: broken links (ids that exist *nowhere* — stub-aware), id/filename mismatches, and a coverage report of outstanding stubs. Exit non-zero on hard errors. (The exporter already does a version of this — factor it out so both the exporter and a CI step can call it.)
- Acceptance: passes on current content; fails loudly if a link points to a non-existent, non-stub id.

## Out of scope (needs content first, or is design-owned)
- The genealogy / map / timeline views — defer until there's enough content to be meaningful (the design chat will signal when).
- Authoring any entry prose, choosing verse, or resolving anything in `QUESTIONS_FOR_DESIGN.md`.

## Done = 
All four acceptance checks pass, `BUILD_LOG.md` updated, work committed on an `infra/` branch, `node_modules`/`build` still gitignored.
