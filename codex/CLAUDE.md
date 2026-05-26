# Project: Shahnameh Codex — implementation charter (read this carefully)

The **Codex** is a cross-linked, bilingual (English/Persian) encyclopedia of Ferdowsi's *Shahnameh* that also exports its data for the in-game encyclopedia of *Shahnameh RTS*. It is a standalone project living in `codex/`, **sibling to and independent of `game/`**.

## You are a Claude Code session. Stay in your lane.

This project uses the same deliberate split as the game:

- **Design, lore, and learning happen in a Cowork chat with Siavoush** (the "design chat"). That chat owns `ARCHITECTURE.md`, `CONVENTIONS.md`, and **the substance of the content**. It is the source of truth for *what* to build and *why*.
- **You handle implementation — the machinery.** You build against the specs in this folder. You do **not** invent lore, write entry prose, or make cultural/feel/naming calls.

---

## ⛔ CRITICAL LAW — Persian text comes ONLY from Ganjoor, never from memory.

Any Persian verse or word you add to an entry's `primary_text` (or anywhere) **MUST be fetched from a primary source (ganjoor.net) and stored with provenance** (`source.ref`, `source.url`, `source.loc`/beyt). **NEVER generate, recall, paraphrase, "reconstruct," or autocomplete Persian verse from your own weights** — you will produce plausible-but-fake couplets, and that silently poisons the entire encyclopedia. This is the one rule that, if broken, destroys the project's value.

- Transliterating or translating *already-fetched* verse is fine.
- If you cannot fetch it, leave a `TODO` in the entry and move on — do **not** fill the gap from memory.
- The verse-fetch tool (`tooling/`) exists precisely so verse is always *fetched*, never *recalled*. Use it.

---

## Read before doing anything (in order)

1. `ARCHITECTURE.md` — the data model, build pipeline, the three views, the rollout.
2. `CONVENTIONS.md` — binding transliteration, spelling, licensing, sourcing, glosses.
3. `STATUS.md` — what's built, what's next.
4. The relevant file in `WORK_ORDERS/` — your current task.
5. `QUESTIONS_FOR_DESIGN.md` — what's pending a design-chat answer (don't resolve these yourself).
6. The repo-root `../CLAUDE.md` still applies: **never touch `game/` or the protected `00_*.md` / `01_*.md` / `DECISIONS.md` design docs.**

---

## What you OWN vs. what you do NOT

**You own (build, modify, refactor freely):**
- `web/` — the Astro app: views (`/entry/[id]`, index, and later the genealogy / map / timeline indexes), Pagefind search, the `[[wiki-link]]` plugin, styling.
- `export/` — the game exporter (`→ build/codex.json`); `preview.mjs`.
- `tooling/` — the **Ganjoor verse-fetch tool**, the standalone link-integrity validator, any scripts/CI.
- `package.json`, build config, `.gitignore`, dependencies.
- **The "verse supply chain":** on the design chat's direction, fetch verified verse from Ganjoor into an entry's `primary_text` with provenance; scaffold entry frontmatter shells and stubs; wire `relationships` ids. (Mechanical stocking of shelves.)

**You do NOT author (design-owned — escalate or leave it):**
- The **substance** of entries: the `## Story`, `## History`, `## Game lens` prose; which episodes to cover; what the verse *means*; the "Ferdowsi says X vs. scholars hypothesize Y" framing.
- Lore, cultural framing, feel, and any naming/transliteration **not already fixed in `CONVENTIONS.md`**.
- `ARCHITECTURE.md`, `CONVENTIONS.md` — read-only from your side. Propose changes via `QUESTIONS_FOR_DESIGN.md`; don't edit them.
- `schema/entrySchema.mjs` — you implement against it, but a schema **change** that alters content shape must be agreed with the design chat first (it's the contract both consumers depend on).

**One-line boundary: build the machine and stock the shelves with verified raw material; do not write the encyclopedia's prose or make its judgment calls.**

---

## Escalation — when the spec is silent

1. **Pure implementation choice, no visible effect on content or feel** (data structure, file layout, a Pagefind setting, a CSS detail) → decide it yourself, prefer the simplest option, note it in code/`BUILD_LOG.md`.
2. **Anything touching lore accuracy, cultural framing, entry substance, feel, or naming/transliteration not already in `CONVENTIONS.md`** → **STOP.** Append the question to `QUESTIONS_FOR_DESIGN.md` with enough context to answer cold, and continue with whatever else is unblocked. Bias: when in doubt, ask.

The open naming calls (Siavash/Siavoush, Simorgh/Simurgh, Haft Khan/Haft Khwan, Sekandar's `register`) are already in `QUESTIONS_FOR_DESIGN.md` — use the `aka`/placeholder until answered; do not pick unilaterally.

---

## Binding conventions

- **Transliteration, spelling, false-friend glosses** per `CONVENTIONS.md`. Game-canon spelling wins on conflict.
- **Licensing:** ship only public-domain / our own translations + open-access media. Dick Davis is reference-only — never reproduce wholesale.
- **Verses are cached into the SSOT at author-time** — never a runtime dependency on Ganjoor being up.
- **One schema, two consumers** (`schema/entrySchema.mjs`). Keep it compatible with **both zod v3 (exporter) and zod v4 (Astro)** — e.g. two-arg `z.record(key, value)`.
- **Stub-aware links:** an entry referenced before it's written exists as a `status: stub`; the build fails only on ids that exist *nowhere*.

---

## Coordination (so we don't collide)

- Use branches for non-trivial work: `infra/<short>` or `feat/<short>`.
- **The contended surface is `content/entries/**` and `schema/`.** The design chat (Cowork) is the primary editor of entry *substance*. If you must touch an entry body, prefer mechanical frontmatter / `primary_text` edits and coordinate. Schema changes: propose first.
- Before declaring done, **run the full pipeline**: `npm run export` (codex.json), `node preview.mjs`, and the Astro build — verify Persian round-trips and links resolve.

## End of every session

1. Append a dated entry to `BUILD_LOG.md` (what shipped, what didn't, state for the next session).
2. Surface any open `QUESTIONS_FOR_DESIGN.md` items in the log.
3. Commit your work (keep `node_modules/` and `build/` gitignored). Don't leave uncommitted changes.

## Safety net

The repo's `shahnameh-loremaster` agent reviews culturally-load-bearing work. For any entry content you end up touching, you may request a loremaster review; the design chat reviews too.
