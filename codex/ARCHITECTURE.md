# Codex — Architecture & Design

*The Shahnameh Codex: a cross-linked, bilingual encyclopedia that serves as both a learning resource and the eventual in-game "Civilopedia" for Shahnameh RTS.*

**Status:** Design phase. Nothing scaffolded yet. This document is the proposal we agree on before building.
**Owner of this folder:** the Codex side-chat (learning + encyclopedia). Sibling to, and independent of, `game/`.
**Date:** 2026-05-24

---

## 0. What this is, in one paragraph

A Civilopedia for the Shahnameh. Every character, place, event, concept, creature, and (eventually) game unit/building/mechanic is an **entry** — a node in a web of cross-links. The encyclopedia is browsable three ways that are all the *same data seen differently*: a **genealogy tree** (the web sorted by blood), an **interactive map** (sorted by place), and a **dual-track timeline** (sorted by when — with the seam between myth and history made visible). Each entry carries real Ferdowsi verse as its "flavor text," which no commercial game encyclopedia has ever done. It doubles as a learning tool for Siavoush and as shippable game content.

---

## 1. Non-negotiable constraints (decided)

These were locked before design and drive everything below.

1. **One source of truth feeds two consumers: web + game.** The source data must be machine-parseable so the eventual in-game (Godot) encyclopedia reads from the *same* source as the web Civilopedia. Neither consumer owns the data.
2. **A build step is acceptable** (Node or Python). We can compile source → HTML and source → game-JSON.
3. **Local-first, hosting-ready.** Runs from files on disk now; the architecture must not foreclose publishing to a static host later without rework.
4. **Hands off `game/` and the protected design docs.** The Codex *produces* a data artifact for the game; wiring Godot to load it is a separate game-side task. The Codex never writes into `game/`, `00_*.md`, `01_*.md`, `DECISIONS.md`, or `CLAUDE.md`.
5. **Inherit the canon.** Transliteration (Rostam, Afrasiyab, Kay Khosrow), Persian spellings alongside English, "Farr-e Izadi," the source hierarchy (Khaleghi-Motlagh → Dick Davis → Warner & Warner → Encyclopaedia Iranica), and the cultural guardrails from `00_SHAHNAMEH_RESEARCH.md §7` are binding.
6. **Covers the ENTIRE Shahnameh.** The codex spans the whole epic — from Keyumars and the creation through the Sasanian fall and the Arab conquest — *not* just the Kayanian/heroic age the game occupies. The game's content is a strict *subset*: the `game` block on an entry is populated only where that entry corresponds to a shipped (or planned) RTS element, and is absent for everything else. The codex is deliberately a **superset** of game content — it is the complete reference first, and the game's encyclopedia second.

---

## 2. The central architectural idea

> **The single source of truth is a corpus of plain markdown files with structured YAML frontmatter — not any framework, not any database, not the website.**

Everything else is a **consumer** of that corpus:

```
                       ┌─────────────────────────┐
                       │   content/  (THE SSOT)   │
                       │  markdown + frontmatter  │
                       └───────────┬──────────────┘
                                   │  (read by)
                 ┌─────────────────┼──────────────────┐
                 ▼                 ▼                  ▼
        ┌───────────────┐  ┌───────────────┐  ┌────────────────┐
        │  web consumer │  │ game exporter │  │ (future) other │
        │   (Astro)     │  │  → codex.json │  │   consumers    │
        │  → static site│  │  for Godot    │  │                │
        └───────────────┘  └───────────────┘  └────────────────┘
```

Why this matters, and why it directly answers your "don't fall into a framework just because training data says so" concern: **if Astro is ever the wrong choice, the SSOT survives untouched and we swap one consumer.** The data is never trapped inside a tool. The web framework is a rendering detail; the game exporter is a sibling, not a downstream of the website. This is the cheapest possible insurance against lock-in, and it costs us nothing now.

### Why markdown + frontmatter (not pure JSON, not pure prose)

| Option | Structured data (drives tree/map/timeline + game) | Human-authorable long prose (the learning loop) | Verdict |
|---|---|---|---|
| Pure JSON | Excellent | Painful — you can't comfortably hand-write a 600-word story in JSON strings | Rejected |
| Pure/free markdown | None — no reliable relationships, dates, coords | Excellent | Rejected |
| **Markdown + YAML frontmatter** | **Good — typed fields up top** | **Excellent — prose in the body** | **Chosen** |

Structured fields (ids, names, relationships, dates, coordinates, citations, game-links) live in frontmatter; the four narrative sections live in the markdown body. This is exactly the shape Astro's Content Layer + Zod validation is built around, *and* it's trivially parseable by a 30-line export script with `gray-matter`. Both consumers are happy.

---

## 3. The entry — atom of the system

One file per entry: `content/entries/<type>/<id>.md`.

### 3.1 Frontmatter schema (the structured layer)

```yaml
---
id: rostam                       # stable slug, unique, never changes (links depend on it)
type: person                     # person|place|event|concept|dynasty|creature|artifact|
                                 #   passage|faction|unit|building|mechanic
title: Rostam                    # English display name (canon transliteration)
title_fa: رستم                   # Persian
aka: [Rustam, Rustem]            # alternate spellings → search + redirects
age: kayanian                    # pishdadian|kayanian|sasanian|meta
register: legend                 # myth|legend|history  → timeline colour + honesty about the seam
summary: >                       # one line; powers hovercards AND the in-game tooltip
  The greatest hero of the Shahnameh; champion of Iran across generations.

chronology:                      # both tracks; either may be null
  mythic_seq: 240                # integer ordering within the internal Shahnameh sequence
  historical: null               # {start: -224, end: 651} style range, only where real

geo:
  region: sistan                 # → entry id
  coords: [320, 540]             # Leaflet CRS.Simple [y, x] in map units; optional

relationships:                   # typed edges; every value is an entry id (validated!)
  father: [zal]
  mother: [rudabeh]
  child: [sohrab, faramarz]
  mount: [rakhsh]
  kills: [sohrab, esfandiyar, div-e-sepid]
  enemy_of: [afrasiyab]

primary_text:                    # the Ferdowsi "flavour text" — structured for reuse
  - fa: "تهمتن چنین داد پاسخ بدوی"
    translit: "Tahamtan chonin dād pāsokh bedoy"
    en: "Thus Tahamtan gave him his answer"
    source: {ref: ganjoor, loc: "..."}   # provenance is mandatory for verse

game:                            # optional bridge to the RTS (only when relevant)
  maps_to: [unit-rostam]
  anchor_category: null          # links to docs/ANCHOR_CATEGORY_TAXONOMY.md when a building

sources: [davis, khaleghi-motlagh, iranica-rostam]   # → content/sources.yaml ids
related: [haft-khan, zal, rakhsh]                    # manual "see also"
status: draft                    # stub|draft|complete  → progress tracking + build badges
tags: [hero, sistan, pahlavan]
---
```

### 3.2 Body (the prose layer) — the per-entry template

Four canonical H2 sections, in this order, with stable slugs so both the website *and* the game exporter can split them reliably:

```markdown
## Story            <!-- the narrative: causal + emotional logic, not a plot summary -->
## History          <!-- origin scholarship (Avestan/Saka/comparative myth) OR explicit "pure myth"; keep "the text says X" separate from "scholars hypothesize Y" -->
## Primary text     <!-- renders the frontmatter `primary_text` verses, Fa + translit + En -->
## Game lens        <!-- what this maps to in the RTS; links into game/ design where relevant -->
```

This is the learning loop (story → primary text → design lens) frozen into the data shape, so building the encyclopedia *is* the learning.

### 3.3 Cross-links — the soul of the thing

- **In prose:** Obsidian-style `[[rostam]]` or `[[rostam|the great hero]]`. A build step resolves these to links. A link may target a **stub** (a frontmatter-only entry with `status: stub`) that renders as a "not yet written" page — so we can reference Sohrab before `sohrab.md` exists. The build fails only on links to ids that exist *nowhere* (genuine typos), and emits a **coverage report** of outstanding stubs. This is what keeps link-integrity compatible with build-as-we-go.
- **In frontmatter:** every relationship/source/related value is an entry id, validated the same way.
- **Backlinks ("Mentioned in"):** auto-generated. Every entry page lists who links *to* it. This is the rabbit-hole engine — the thing that made you lose forty minutes in Civ's pedia as a kid.
- **Hovercards:** hovering a link shows the target's `summary`. Cheap, and it makes the web feel alive.

### 3.4 Movement — location is a property of *events*, not people

A character is not in one place. Rostam ranges from Zabolestan to Mazandaran to Turan; Siyavash is born in Iran and exiled to Turan, where he dies. A single `geo.coords` on a *person* is therefore wrong — it can only ever freeze one position out of a life of movement.

The fix follows the architecture's own grain: **a person's location is not stored; it is *derived*.** Location is a property of **events**, and a person's trajectory is the ordered sequence of the places of the events they take part in.

- A **person** entry keeps only a static anchor: `origin` (birthplace) and optionally `seat` (home base) — e.g. Rostam's `origin: zabolestan`. Not "where they are," just "where they're from."
- An **event** entry carries the spatiotemporal facts:

```yaml
---
id: exile-of-siyavash
type: event
age: kayanian
register: legend
chronology: { mythic_seq: 312 }
geo: { region: turan }                              # where it happens
participants: [siyavash, afrasiyab, piran-viseh]    # validated entry ids
movement:                                           # OPTIONAL — journey/displacement events only
  who: [siyavash]
  from: iran
  to: turan
  route: [iran, jeyhun, turan]                       # optional waypoints for the map arrow
---
```

- A **person's path** is then a build-time query: take every event with this person in `participants` (or `movement.who`), sort by `chronology.mythic_seq`, read off the places. That polyline *is* their journey — generated, never hand-maintained.

This buys three things for free:

1. **No duplication, no divergence.** The place + time + cast of an episode lives in exactly one entry (the event). People never re-state it.
2. **The map couples to the timeline.** Every position is timestamped by `mythic_seq`, so scrubbing the timeline can slide characters along their paths — the most "alive" thing the map can do, at zero extra data cost.
3. **Movement is first-class lore.** "The exile of Siyavash" *is* an entry with its own Story / History / Game-lens — so the trajectory and the narrative are the same object.

`movement.from/to/route` lets the map draw a displacement arrow even before intermediate event entries exist — a low-fidelity path now, refinable into real waypoints later.

---

## 4. The three visual indexes are *projections*, not separate data

Each view is a query over the same entry set, generated at build time. No view has its own database.

| View | Source fields | Library (2026, justified) | Notes |
|---|---|---|---|
| **Genealogy tree** | `relationships.father/mother/spouse/child` | **`family-chart`** (d3-based, maintained) with `d3-dag` as fallback | Real Shahnameh blood is a DAG, not a tree (Iranian–Turanian unions, e.g. Siyavash×Farangis). family-chart handles unions/multiple parents. |
| **Map** | `geo.coords`, `geo.region` + `content/map/regions.yaml` | **Leaflet `CRS.Simple`** image overlay + markers | Standard, stable, non-geographic. A stylized Iran/Turan/Mazandaran base image; markers link back to entries. |
| **Timeline** | `chronology.mythic_seq`, `chronology.historical`, `register` | **`vis-timeline`** (community-maintained) | Two **groups** = the dual track: internal mythic sequence vs real history. Colour by `register` (myth/legend/history) so the **seam is visible** — dramatizing the very thing the game is about. |
| **Full-text search** | everything | **Pagefind** (static, zero-infra) | The 2026 standard for static-site search; indexes at build, runs in the browser, no server. |

All four are wired to the SSOT, so adding an entry automatically populates every index — no double-entry bookkeeping.

---

## 5. Build pipeline & toolchain

**Web consumer — Astro (latest, v6-era) with the Content Layer API.**
- `glob()` loader over `content/entries/**/*.md`; `file()` loader for `sources.yaml`, `regions.yaml`.
- **Zod schema** validates every entry's frontmatter at build — a missing `title`, a bad `register`, or a relationship id that resolves to no entry (not even a stub) all fail the build, not production.
- Pages: `/entry/[id]`, `/tree`, `/map`, `/timeline`, `/` (index + Pagefind search).
- Output: static HTML, zero client JS except on the interactive index pages (Astro islands). Drops onto any static host later → satisfies "hosting-ready" for free.

**Game consumer — a small standalone export script (`export/export.mjs`).**
- Reads the **same** `content/` markdown directly with `gray-matter` (does *not* depend on Astro).
- Emits `build/codex.json`: normalized entries with prose sections as plain text / Godot BBCode, Persian preserved as UTF-8.
- Godot reads that JSON with `FileAccess` + `JSON.parse_string` (native, no plugin). **Wiring the game to consume it is a game-side task; the Codex only produces the artifact in `codex/build/`.**

**One schema, two consumers.** The Zod schema is the canonical definition; the export script imports the same module (hence both consumers are Node) so the schema is written once. Godot trusts the validated export and does not re-validate.

### Why Astro over the alternatives (the controlled comparison)

- **Astro** — chosen. Content collections + Zod give build-time validation, the `file()`/`glob()` split fits our SSOT exactly, island architecture keeps the static pages JS-free while allowing the three interactive views. Strongest fit for "structured source → HTML + clean separation."
- **Quartz** — the digital-garden native; backlinks + graph view *for free*. Tempting, but it's coupled to an Obsidian-vault mental model and is opinionated about output; bending it to *also* emit a game-JSON and custom map/timeline fights the tool. Rejected as the spine; we borrow its backlink idea.
- **Eleventy** — the minimalist "content+templates→HTML." Viable fallback if Astro proves heavy, but we'd hand-build the schema validation and search wiring Astro gives us out of the box.
- **Custom static generator** — maximum control, but we'd be reinventing routing, validation, and search. The SSOT-decoupling already gives us the lock-in protection a custom build would, without the maintenance.

---

## 6. Proposed folder layout

```
codex/                      # NEW top-level project, sibling to game/  (never touches game/)
├── README.md               # what it is, how to run
├── ARCHITECTURE.md         # this document
├── content/                # ← THE SSOT. Plain, portable, framework-free.
│   ├── entries/
│   │   ├── people/         #   rostam.md, jamshid.md, zahhak.md, ...
│   │   ├── places/         #   mount-damavand.md, mazandaran.md, sistan.md, ...
│   │   ├── events/         #   division-of-the-world.md, kaveh-revolt.md, ...
│   │   ├── concepts/       #   farr.md, derafsh-e-kaviani.md, ...
│   │   ├── creatures/      #   div-e-sepid.md, simorgh.md, ...
│   │   └── game/           #   unit-rostam.md, building-atashkadeh.md, mechanic-farr.md
│   ├── sources.yaml        # bibliographic refs (davis, ganjoor, iranica, khaleghi-motlagh)
│   ├── map/
│   │   ├── base-map.<img>  # stylized Iran/Turan/Mazandaran image
│   │   └── regions.yaml    # region polygons/labels
│   └── config/             # enums: ages, types, registers (single definition)
├── schema/                 # the Zod schema (the one definition both consumers honor)
├── web/                    # Astro consumer → static site
│   └── (package.json, astro.config.*, src/, ...)
├── export/                 # game consumer → codex.json
│   └── export.mjs
└── build/                  # generated artifacts (gitignored): web/dist, codex.json
```

---

## 7. Rollout — controlled, build-as-we-go

Each phase ends in a checkpoint where we can stop, evaluate with *real* data, and change course cheaply (the SSOT makes swaps safe).

**Phase 0 — Tracer bullet (before scaling content).** Scaffold the folder, schema, Astro skeleton, and export script. Author **exactly two entries** (`farr` and `rostam`) and prove the whole path end-to-end: they render as cross-linked web pages *and* appear correctly in `codex.json` with Persian intact. Validates the architecture on the smallest possible surface before we commit to it.

**Phase 1 — Entries + links + search.** Entry pages, `[[wiki-links]]`, backlinks, hovercards, Pagefind search. Begin the learning loop: the **Jamshid → Zahhak → Kaveh → Fereydun → division-of-the-world** arc becomes our first cluster of real entries (it seeds both the Iran–Turan war and the Farr concept — maximum leverage).

**Phase 2 — The visual indexes.** Add them cheapest-first: **timeline** (most pedagogically powerful, dramatizes the seam), then **genealogy**, then **map**.

**Phase 3 — Game export hardening + handoff.** Finalize `codex.json` shape, document the contract, hand off to a game-side session to wire Godot.

**Hosting** is deferrable indefinitely: Astro's static output publishes anywhere with no core change.

### Controlled-experiment checkpoints
- After Phase 0: does Astro *feel* right at small scale? If not, the SSOT is intact — swap the web consumer.
- After Phase 2: do the viz libraries hold up at real data volume? Re-evaluate `family-chart`/`vis-timeline`/Leaflet with actual entries, not assumptions.

---

## 8. Decisions — resolved this round, and what still needs your call

**Resolved**

1. **Chronology = ordering, not fake years (agreed).** Order by `mythic_seq` (integer) within `age`; never fabricate dates for mythic material. Real date ranges only where history allows (`chronology.historical`).
2. **Origins research feeds the "History" section (your refinement).** Each entry's History traces the real-world / scholarly roots of the myth — the Avestan layer (e.g. Jamshid ← *Yima*), Saka/Scythian strata (the Rostam/Sistan cycle), comparative mythology, historicization debates — citing Encyclopaedia Iranica and academic work. **Hard discipline (loremaster caution):** keep a visible wall between *"Ferdowsi's text says X"* (canon) and *"scholars hypothesize the origin is Y"* (reconstruction). Hypotheses are attributed and never presented as canon — the same honesty the timeline's myth/history seam enforces.
3. **Primary-text verses live in frontmatter (you liked it)**, rendered into the body's "Primary text" section.
4. **Farr spelling — verified; the research doc is wrong.** The loremaster confirmed against Dehkhoda + Encyclopaedia Iranica that the divine glory is **فرّ** (*farr*), with **فرّ ایزدی** (*farr-e izadi*) and **فرّ کیانی** (*farr-e kiani*) for the divine and Kayanian forms. `00_SHAHNAMEH_RESEARCH.md §5`'s **خرمن کیانی** is a transcription error (خرمن = "harvest/threshing-floor"). The codex uses فرّ; `farr.md` carries a one-line note recording the corrected lineage. (The old §8.4 content question, now closed.)
5. **Sources include the full primary text (your note).** `content/sources.yaml` registers **Ganjoor** (ganjoor.net — the complete Persian text verse-by-verse, the canonical free digital edition and our verbatim-verse fetch source), **Warner & Warner** (complete, public-domain English), **Dick Davis** (best modern English), **Khaleghi-Motlagh** (critical edition), and **Encyclopaedia Iranica** (per-character reference). Verses are *fetched from Ganjoor*, never recalled from memory.

**Still needs your call (content, not architecture)**

6. **A few spellings to lock** — the loremaster flagged divergences. Game-canon wins for consistency, but these are judgment calls:
   - **Siavash vs Siavoush** — your own name is the latter; scholarly is *Siyāvaš*. Pick the `title`; the other goes in `aka`.
   - **Simorgh vs Simurgh** — the research doc uses "Simurgh"; "Simorgh" is closer to سیمرغ. Pick one for the `id`.
   - **Haft Khan vs Haft Khwan** — research doc uses "Khwan"; the simplest `id` is `haft-khan`.
   - **Sekandar (Alexander)** straddles legend/history — a deliberate `register` call when we author him.

**Deferred**

7. **Persian RTL in-game** — Godot reads UTF-8 fine; right-to-left rendering in the *game* UI is finicky but a downstream game-side concern. We cross that bridge later.

---

## 9. What this explicitly is NOT

- Not a fork of `00_SHAHNAMEH_RESEARCH.md` or the design canon — it *cross-references* them; the canon stays the canon.
- Not a database or CMS — the SSOT is flat files in git, diffable and portable.
- Not locked to Astro — Astro is one swappable consumer of the SSOT.
- Not allowed to modify `game/` — it produces an artifact; the game consumes it via a separate task.

---

## 10. Round-2 refinements (decided 2026-05-24)

- **Stub-aware links** (supersedes the earlier "fail on any unresolved link"): links may point to `status: stub` entries; the build fails only on ids that exist *nowhere*, and reports outstanding stubs. Keeps link-integrity compatible with build-as-we-go. See §3.3.
- **Genealogy & map at full-epic scale:** the genealogy view focuses on a selected node's ancestors/descendants rather than rendering the whole epic at once; the map clusters markers. Neither view dumps the entire dataset.
- **Media fields:** entries may carry `media: { images: [...], audio: [...] }` (manuscript miniatures, Ganjoor recitations), each item with its own `source` + `license`.
- **Sourcing, licensing, variants, verse-caching** are specified in `CONVENTIONS.md §5–5.1`. Headlines: ship only public-domain / our own translations + open-access art (Davis is reference-only); Khaleghi-Motlagh is the canonical reading; verses are cached into the SSOT at author-time, never a runtime dependency on Ganjoor.
