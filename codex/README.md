# Codex

The **Shahnameh Codex** — a cross-linked, bilingual (English/Persian) encyclopedia of Ferdowsi's *Shahnameh*. It is two things at once:

1. A **learning resource** — built up episode by episode as Siavoush works through the epic.
2. The eventual **in-game "Civilopedia"** for Shahnameh RTS — the same source data, exported for the game to consume.

This folder is a **standalone project, sibling to `game/`**. It never modifies `game/` or the protected design docs (`00_*.md`, `01_*.md`, `DECISIONS.md`, `CLAUDE.md`); it cross-references them.

## How it works (one line)

A corpus of plain markdown files with structured frontmatter (`content/`) is the single source of truth. A web consumer (Astro) renders it into a browsable static site; a game exporter turns the *same* files into `codex.json` for Godot.

## Read first

**[ARCHITECTURE.md](ARCHITECTURE.md)** — the full design: data schema, build pipeline, the three visual indexes (genealogy / map / timeline), library choices with rationale, and the phased rollout.

## Status

Design phase. Nothing scaffolded yet — the architecture is up for review before any build begins.
