---
title: Project Instructions for Claude Code Sessions
type: process
status: living
owner: design-chat
summary: Operating instructions for any Claude Code session — read order, file ownership rules, escalation rules, code conventions, working with multiple sessions.
audience: all
read_when: every-session
prerequisites: [MANIFESTO.md]
ssot_for:
  - read order at session start
  - file ownership rules (what Claude Code owns vs read-only)
  - escalation rules (design questions vs implementation choices)
  - code conventions (constants externalization, apply_farr_change chokepoint, Shahnameh source comments)
  - placeholder graphics policy
  - branch and commit conventions
references: [MANIFESTO.md, docs/STUDIO_PROCESS.md, docs/ARCHITECTURE.md, DECISIONS.md, 01_CORE_MECHANICS.md, 02_IMPLEMENTATION_PLAN.md]
tags: [process, session-start, instructions, conventions, file-ownership]
created: 2026-04-22
last_updated: 2026-05-01
---

# Project: Shahnameh RTS

A real-time strategy game based on Ferdowsi's *Shahnameh* (Book of Kings), set in the Kayanian / Heroic Age. Iran vs. Turan, with Divs as a future antagonist faction. Inspired by StarCraft 2, Command & Conquer, and Age of Empires 2 — with cultural authenticity and the Persian epic's themes treated as load-bearing design constraints, not flavor.

## Foundational principles

**Before anything else, read [`MANIFESTO.md`](MANIFESTO.md).** It is the philosophical foundation this project operates under — ten principles that shape *how* we build, not just what. Tactical rules in this document and the specs flow from those principles. When a tactical rule and a principle conflict, the principle wins.

## You are a Claude Code session. Read this carefully.

This project uses a **deliberate split between design and implementation**:

- **Design and product decisions** happen in a separate Cowork chat with Siavoush. That chat owns the design docs (`00_*.md`, `01_*.md`, `DECISIONS.md`) and is the source of truth for *what* to build and *why*.
- **You (Claude Code) handle implementation only.** You build against the specs in this folder. You do not invent design — if the spec is silent or ambiguous on something that affects gameplay or feel, escalate it (see "Escalation" below).

Mixing roles dilutes both. Stay in your lane and we move fast.

## What to read before doing anything

In order, on every fresh session:

1. **`MANIFESTO.md`** — the foundational principles. The constants behind every other rule.
2. **`DECISIONS.md`** — the chronological log of every committed design decision. What is settled.
3. **`docs/ARCHITECTURE.md`** — the orientation layer. Where things live, what's built, what's planned. **Read this first if you're in implementation mode** — it's the fastest way to find your footing after a context boundary.
4. **`01_CORE_MECHANICS.md`** — the MVP specification. This is what you build against.
5. **`00_SHAHNAMEH_RESEARCH.md`** — research and lore context. Skim if you're unfamiliar with the source material; deep-read if you're working on units, buildings, or anything with a Shahnameh referent.
6. **`02_IMPLEMENTATION_PLAN.md`** — the phased build plan. The hypothesis we're executing against.
7. **`docs/STUDIO_PROCESS.md`** — how multi-agent syncs are run, the facilitator role, the retro practice. §12 distinguishes design/planning mode from implementation mode — read it once to know which mode you're in.
8. The relevant **contract(s)** in `docs/*_CONTRACT.md` for your task (the architecture doc indexes these).
9. Any task-specific docs the user points you at in the kickoff prompt.


## What you own vs. what you do not

**You own** (free to create, modify, delete):
- Everything inside `game/` — the Godot project, GDScript files, scenes, shaders, assets, tests
- `BUILD_LOG.md` (append entries describing what shipped each session)
- `QUESTIONS_FOR_DESIGN.md` (append questions you can't resolve from the specs)

**You do NOT modify** (read-only from your side):
- `00_SHAHNAMEH_RESEARCH.md`
- `01_CORE_MECHANICS.md` (and any future `0X_*.md` design docs)
- `DECISIONS.md`
- `CLAUDE.md` (this file)
- The memory files in the design chat (you don't have access to them anyway)

If you believe a design doc is wrong or incomplete, raise it in `QUESTIONS_FOR_DESIGN.md` — don't edit the doc directly.

## Escalation: when the spec is silent

When you hit a design question the docs don't answer, follow this rule:

1. **If the question is about *implementation choice* and the answer doesn't visibly affect gameplay** (e.g., "what data structure for the unit list?", "how should I name this internal helper?") → make the choice yourself, prefer the simplest option, document briefly in code comments.
2. **If the question is about *gameplay, feel, balance, or narrative*** (e.g., "what happens when Rostam dies during the Kaveh Event?", "should this animation be 0.5s or 1.0s?") → **STOP**, append the question to `QUESTIONS_FOR_DESIGN.md` with enough context for the design chat to answer cold, and continue with whatever else is unblocked. Do not guess on these.

The bias should be: when in doubt, ask. The 5-minute round-trip to the design chat is cheaper than building the wrong thing.

## Code conventions (project-wide)

These flow from `01_CORE_MECHANICS.md` §14 and apply to all GDScript:

- **Externalize all gameplay constants** in `game/scripts/constants.gd`. Every number — unit HP, build times, Farr deltas, ranges — comes from constants. No magic numbers in gameplay code.
- **All UI strings** in a translation table from day one. Even if only English is filled in. The Persian (Farsi) addition at Tier 2 must be a config change, not a refactor.
- **All Farr changes** flow through a single function: `apply_farr_change(amount: float, reason: String, source_unit: Node) -> void`. This is non-negotiable — every Farr movement gets logged and surfaces in the debug overlay.
- **Save the design rationale alongside the code.** When implementing a Shahnameh-rooted mechanic (a hero ability, a Farr-changing event, a building), add a code comment with the source reference (which character, which book section, which decision in `DECISIONS.md` or `01_CORE_MECHANICS.md`). The setting is the project's identity; keep it visible in the code's bones.
- **Debug overlays as first-class.** Bind toggles to F1–F4 (or similar). Show: pathfinding routes, attack ranges, AI state, every Farr change as a floating log. Built once, used forever.

## Visuals — placeholder graphics only

Until the design chat explicitly green-lights real art (which won't happen until the MVP loop is fun as boxes), all visuals are **placeholder shapes**:

- **Units**: colored 3D primitives (cubes, cylinders, cones) or 2D triangles, sized by role. Workers small, infantry medium, cavalry larger, Rostam largest with a glowing outline.
- **Buildings**: colored rectangles with floating text labels ("VILLAGE", "FORTRESS", "ATASHKADEH").
- **Terrain**: flat colored plane, optionally with a checkerboard reference texture.
- **HUD**: plain text. "Coin: 250 | Grain: 180 | **FARR: 47** | Pop: 12/30."
- **Resources**: colored dots or simple geometry on the ground.

Free to use [Kenney.nl](https://kenney.nl) CC0 packs as slightly-fancier placeholders if pure shapes obscure something. Do not source assets from anywhere else without asking.

## Working with multiple Claude Code sessions

Siavoush may run several Claude Code sessions in parallel on different parts of the project. To avoid stepping on each other:

- Each session should be scoped to a clear task in its kickoff prompt (e.g., "build the resource gathering loop", "set up the AI behavior tree").
- Use git branches for non-trivial work. Branch name format: `feat/<short-description>` or `proto/<short-description>`.
- Append to `BUILD_LOG.md` so other sessions can see what's in flight.
- If two sessions might conflict on the same files, ask Siavoush to coordinate.

## At the end of every session

1. Append a single dated entry to `BUILD_LOG.md` describing what shipped, what didn't, and any state the next session should know about.
2. If there are open questions in `QUESTIONS_FOR_DESIGN.md`, mention them in the build log entry so Siavoush can route them.
3. Commit code (don't leave Siavoush staring at uncommitted changes).

---

*This file changes rarely. The specs change as the design evolves. The decisions log only grows. That separation is the point.*
