---
title: Agent Registry — Persistent-instance addressable names + status
type: log
status: living
version: 2.0.0
owner: team-lead
summary: Canonical registry of persistent agent instances + their SendMessage addressable names + spawn provenance + current status. Read BEFORE any SendMessage dispatch to verify the addressable name (agent-def file names ≠ instance addressable names).
audience: all
read_when: every-dispatch, every-session-start, before-any-SendMessage-to-a-persistent-instance
prerequisites: [STUDIO_PROCESS.md §9.G]
ssot_for:
  - Per-instance addressable names (the string used in SendMessage `to:` field)
  - Agent-def file → addressable-name mapping
  - Persistent-instance spawn provenance (when did this instance come into being)
  - Per-instance current status (active / dormant / decommissioning / decommissioned)
  - Per-agent-def model policy (which model each role runs and why)
references: [STUDIO_PROCESS.md §9.G + §12.5.1, .claude/agents/]
tags: [process, registry, agents, sendmessage, routing, model-policy]
created: 2026-05-21
last_updated: 2026-06-08
---

# Agent Registry

> **Why this doc exists.** SendMessage routes by addressable name (a free-form string). Agent-def file names in `.claude/agents/` (e.g., `gameplay-systems.md`) are NOT the same as the addressable names persistent instances answer to (e.g., `gp-sys-p3s3`). When lead routes to the wrong name, SendMessage returns `success: true` but the message lands in a phantom inbox — silent failure mode. **This registry is the canonical source of truth for which addressable names are live.**

> **Canonical incidents (N=3):** (1) 2026-05-21 Wave 2B Track 1 — `gameplay-systems-p3s3` instead of `gp-sys-p3s3`, 3 messages phantom. (2) 2026-05-28 session-9 retro — `world-builder-p3s3` + `ai-engineer-p3s3` phantom (instances never existed). (3) 2026-06-04 Wave 3-Sim Track 2 — `engine-architect-p3s3` instead of `engine-architect-p3s2` (~82 min stall; **suffix tracks BIRTH-session, not current-session**). **Memory file:** `feedback_lead_sendmessage_routing.md`.

## Naming convention

Persistent-instance addressable names follow the format:

```
<short-or-full-name>-p<phase>s<session>[-<role-suffix>]
```

- `<short-or-full-name>`: SOMETIMES the full agent-def name (e.g., `world-builder`), SOMETIMES a short form (e.g., `gp-sys` for `gameplay-systems`). **No consistent rule** — verify per instance.
- `p<phase>s<session>`: phase + session-number when the instance was **first spawned** (birth-session). Persists across sessions per §12.5.1; the original spawn phase/session stays in the name even as sessions advance.
- `-<role-suffix>` (optional): only for special-purpose instances.

## Pre-dispatch verification protocol (BLOCKING — first action of every session)

Before ANY SendMessage to a persistent instance:

1. **Reconcile this registry against the live inbox list at session start** — ask the user for the inbox list if it isn't visible; commit the registry diff BEFORE any dispatch. (Codified after the protocol was skipped at sessions 9-10 and phantom-inbox incidents recurred despite this registry existing.)
2. **Check this registry.** Use the exact addressable name from the "Addressable name" column.
3. **Cross-check against the most recent `<teammate-message teammate_id="X">` block** from that instance — the `teammate_id` is authoritative; if registry disagrees, update the registry.
4. **Never derive a name from the agent-def file name or the current session number.**

## Model policy (set 2026-06-08, Fable-5-era — see §12.5.1 generational-reboot)

| Agent-def | Model | Rationale |
|---|---|---|
| `mirror-reviewer.md` | **inherit** (no pin — runs session model) | Highest-judgment adversarial role; documented hours-saved ROI; inherit future-proofs the next model upgrade |
| `architecture-reviewer.md` | **inherit** (no pin) | Same class — integration-time mirror is a §9.F6 hard gate; judgment quality is the product |
| `balance-engineer.md` | opus (was sonnet) | Phase 4 primary specialist; tuning-loop design is judgment-heavy; shipped one semantic bug on sonnet |
| `qa-engineer.md` | opus (was sonnet) | Sim-tooling + aggregation waves are correctness-critical; fixture-drift incident on sonnet |
| `world-builder.md` | opus (was sonnet) | BUG-D1/D2 silent-correctness history on sonnet; applies at next activation |
| `engine-architect.md` | opus | Strong track record on opus; re-evaluate after 3 Fable-led waves |
| `gameplay-systems.md` | opus | Same |
| `godot-code-reviewer.md` | opus | Checklist-driven role; pitfall-list lookup does not need the strongest model |
| `peiman-manifesto-reviewer.md` | opus | Fresh-eyes naivety is the value; stronger model not the bottleneck |
| `shahnameh-loremaster.md` | opus | Cultural-judgment quality currently high; re-evaluate if J4 confidence-disclosure quality drops |
| `ai-engineer.md` | opus | DORMANT — re-pin decision deferred to Phase 6 reactivation (spawn fresh on strongest available model then) |
| `ui-developer.md` | opus | DORMANT — same deferral |

## Current instances (Phase 3 → 4 boundary, 2026-06-08)

**Generation 1 (Phase 3) — DECOMMISSIONED 2026-06-08.** Per the §12.5.1 model-tier-change reboot condition, the model re-pins above required fresh spawns. The intended instance-written handoffs could NOT be collected: the runtime teardown at the lead's model upgrade cleared the teammate roster before handoff requests delivered (all six SendMessage attempts returned "no agent addressable"). Handoffs were **lead-reconstructed from each instance's session-10 close-retro reflections + final broadcasts** (high fidelity for the four heavy session-10 participants; BUILD_LOG-reconstruction fidelity for gp-sys / world-builder / ui-developer) and archived to `docs/AGENT_HANDOFFS_PHASE3.md`. **Lesson codified there: request handoffs BEFORE any planned runtime restart.**

| Agent-def | Addressable name | Spawned | Status |
|---|---|---|---|
| `gameplay-systems.md` | `gp-sys-p3s3` | P3 s3 | Decommissioned 2026-06-08 — runtime teardown; handoff reconstructed |
| `world-builder.md` | `world-builder-p3s2` | P3 s2 | Decommissioned 2026-06-08 — runtime teardown; handoff reconstructed |
| `balance-engineer.md` | `balance-engineer-p3s3` | P3 s3 | Decommissioned 2026-06-08 — runtime teardown; handoff reconstructed |
| `ui-developer.md` | `ui-developer-p3s3` | P3 s3 | Decommissioned 2026-06-08 — dormant since s8; no live carry-forwards |
| `engine-architect.md` | `engine-architect-p3s2` | P3 s2 | Decommissioned 2026-06-08 — runtime teardown; handoff reconstructed |
| `shahnameh-loremaster.md` | `shahnameh-loremaster-p3s5` | P3 s5 | Decommissioned 2026-06-08 — runtime teardown; handoff reconstructed |
| `qa-engineer.md` | `qa-engineer-p3s3` | P3 s3 | Decommissioned 2026-06-08 — runtime teardown; handoff reconstructed |
| `ai-engineer.md` | (none — phantom since Phase 0) | — | Dormant. TuranController/DummyIranController ownership transferred to `gameplay-systems` until Phase 6 opponent-AI work; spawn fresh then |
| `architecture-reviewer.md` | per-dispatch fresh spawn | — | On-demand (Mode A persistent variant retired with gen 1) |
| `godot-code-reviewer.md` | per-dispatch fresh spawn | — | On-demand |
| `mirror-reviewer.md` | per-dispatch fresh spawn | — | On-demand |
| `peiman-manifesto-reviewer.md` | per-PR fresh spawn | — | On-demand (never persistent, by design) |

**Generation 2 (Phase 4) — spawned on demand.** First dispatch of each role in Phase 4 creates the gen-2 instance on the new model policy. Add rows here at spawn time with birth-session suffixes (e.g., `gp-sys-p4s1`).

## Retro/heartbeat fan-out rule

Retro and heartbeat dispatches go ONLY to registry-verified live instances (status Active or Decommissioning). Dormant and decommissioned rows never receive dispatches — this is the structural fix for the phantom-retro-dispatch incidents at sessions 9-10.

## Registry maintenance protocol

- **Session-start:** reconciliation is a BLOCKING first action (see protocol step 1).
- **New spawn:** add row immediately.
- **Reboot/respawn:** new row for the new instance; old row → `Decommissioned <date> — <reason>` (audit trail, never delete).
- **Lead owns the registry**; any agent can flag mismatches via SendMessage.

## Version history

- **v2.0.0 (2026-06-08):** Phase 3→4 generational boundary. Model-policy table added (Fable-5-era re-pins: mirror + architecture-reviewer → inherit; balance/qa/world-builder → opus). All gen-1 instances marked decommissioning with handoff requests. Dormancy + fan-out rules added (PROC-3/PROC-7 findings). N=3 incident log. Blocking session-start reconciliation.
- **v1.0.0 (2026-05-21):** Initial registry after Wave 2B Track 1 routing failure.
