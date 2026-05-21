---
title: Agent Registry — Persistent-instance addressable names + status
type: log
status: living
version: 1.0.0
owner: team-lead
summary: Canonical registry of persistent agent instances + their SendMessage addressable names + spawn provenance + current status. Read BEFORE any SendMessage dispatch to verify the addressable name (agent-def file names ≠ instance addressable names).
audience: all
read_when: every-dispatch, every-session-start, before-any-SendMessage-to-a-persistent-instance
prerequisites: [STUDIO_PROCESS.md §9.G]
ssot_for:
  - Per-instance addressable names (the string used in SendMessage `to:` field)
  - Agent-def file → addressable-name mapping
  - Persistent-instance spawn provenance (when did this instance come into being)
  - Per-instance current status (active / paused / rebooted / decommissioned)
references: [STUDIO_PROCESS.md §9.G, .claude/agents/]
tags: [process, registry, agents, sendmessage, routing]
created: 2026-05-21
last_updated: 2026-05-21
---

# Agent Registry

> **Why this doc exists.** SendMessage routes by addressable name (a free-form string). Agent-def file names in `.claude/agents/` (e.g., `gameplay-systems.md`) are NOT the same as the addressable names persistent instances answer to (e.g., `gp-sys-p3s3`). When lead routes to the wrong name, SendMessage returns `success: true` but the message lands in a phantom inbox — silent failure mode. **This registry is the canonical source of truth for which addressable names are live.**

> **Canonical incident:** 2026-05-21 Wave 2B Track 1 dispatch. Lead sent Track 1 + heartbeat #1 + heartbeat #2 to `gameplay-systems-p3s3` (agent-def file name) instead of `gp-sys-p3s3` (instance addressable name). Three messages routed to phantom inbox. gp-sys-p3s3 was idle-available the entire time; user intervention surfaced the routing failure. **Memory file:** `feedback_lead_sendmessage_routing.md`.

## Naming convention

Persistent-instance addressable names follow the format:

```
<short-or-full-name>-p<phase>s<session>[-<role-suffix>]
```

- `<short-or-full-name>`: SOMETIMES the full agent-def name (e.g., `world-builder`), SOMETIMES a short form (e.g., `gp-sys` for `gameplay-systems`, `eng-arch` for `engine-architect`). **No consistent rule** — verify per instance.
- `p<phase>s<session>`: phase + session-number when the instance was first spawned. Persists across sessions per §12.5.1; the original spawn phase/session stays in the name.
- `-<role-suffix>` (optional): only for special-purpose instances (e.g., `-retro` — but per §9.G2, retro work routes to existing persistent instances, NOT fresh-spawned `-retro` agents).

## Pre-dispatch verification protocol

Before ANY SendMessage to a persistent instance:

1. **Check this registry first.** Look up the agent-def in the table below; use the exact addressable name from the "Addressable name" column.
2. **Cross-check against the most recent `<teammate-message teammate_id="X">` block from that instance.** The `teammate_id` attribute is the canonical addressable name as the runtime sees it.
3. **If the registry and teammate_id disagree, update the registry** (the teammate_id is authoritative; the registry may be stale).
4. **Never invent a name from the agent-def file name.** `gameplay-systems.md` → DO NOT send to `gameplay-systems-pNsM`. Look it up here.

## Current active persistent instances (Phase 3 session 6)

| Agent-def (`.claude/agents/`) | Addressable name | Spawned | Status | Recent activity |
|---|---|---|---|---|
| `gameplay-systems.md` | **`gp-sys-p3s3`** | Phase 3 session 3 | Active | Wave 2B Track 1 (in flight) |
| `world-builder.md` | **`world-builder-p3s2`** | Phase 3 session 2 | Active | Wave 2A.5 Atashkadeh scene |
| `balance-engineer.md` | **`balance-engineer-p3s3`** | Phase 3 session 3 | Active | Wave 2B Track 3 closed `6503b0c` |
| `ui-developer.md` | **`ui-developer-p3s3`** | Phase 3 session 3 | Active | Wave 2A.5 build menu |
| `engine-architect.md` | **`engine-architect-p3s2`** (also addressable as `eng-arch-p3s2`?) | Phase 3 session 2 | Active | Wave 1D navmesh resolution |
| `shahnameh-loremaster.md` | **`shahnameh-loremaster-p3s5`** | Phase 3 session 5 | Active | Wave 2B Track 0 + Track 5 closed |
| `qa-engineer.md` | (not currently active as persistent) | — | Inactive | Last active session 2 (qa-engineer-p3s2) |
| `ai-engineer.md` | (not currently active as persistent) | — | Inactive | Last active Phase 0 |
| `architecture-reviewer.md` | (spawned per-session for wave-close reviews) | per session | On-demand | — |
| `godot-code-reviewer.md` | (spawned per-session for wave-close reviews) | per session | On-demand | — |
| `peiman-manifesto-reviewer.md` | (fresh-spawn at PR-time only, never persistent) | per PR | On-demand | — |

## Registry maintenance protocol

**When to update:**
- **Session-start:** lead reviews registry against any rebooted/respawned instances per §12.5.1.
- **New instance spawn:** add a row immediately at spawn time (capture phase/session/initial role).
- **Instance reboot/respawn:** update the addressable name + "Spawned" column to the new phase/session.
- **Instance decommission:** mark status `Decommissioned <date> — <reason>` rather than delete (audit trail).

**Who updates:**
- **Lead** owns the registry as the dispatch SSOT.
- **Any agent surfacing a routing-mismatch incident** can flag it via SendMessage; lead updates.

**Version bumps:**
- **PATCH** (1.0.x): status changes, addressable-name corrections, activity-row updates.
- **MINOR** (1.x.0): new persistent-instance class added (e.g., a new specialist role).
- **MAJOR** (x.0.0): naming-convention change.

## Open questions

- **Is `engine-architect-p3s2` also addressable as `eng-arch-p3s2`?** Not yet verified empirically — short-form addressable names exist for some agent-defs (`gp-sys`) but not necessarily all. Will verify at next engine-architect dispatch.
- **Should this registry auto-update from teammate-message routing logs?** Currently manual; could be tool-supported via a runtime registry exposed to the SendMessage tool.

## Version history

- **v1.0.0 (2026-05-21):** Initial registry created in response to Wave 2B Track 1 routing-failure canonical incident. Current Phase 3 session 6 persistent-instance state recorded.
