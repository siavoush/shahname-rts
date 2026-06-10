---
title: Agent Handoffs — Phase 3 generation 1 → Phase 4 generation 2
type: log
status: frozen
version: 1.0.0
owner: team-lead
summary: Serialized handoff state for the Phase-3 persistent-agent generation, decommissioned at the 2026-06-08 Fable-5-era generational reboot (§12.5.1 condition 4). Gen-2 instances read their role's section as a named prerequisite at first Phase-4 dispatch.
audience: all gen-2 agent instances + lead
read_when: first-dispatch-of-your-role-in-phase-4
prerequisites: [docs/AGENT_REGISTRY.md v2.0.0, STUDIO_PROCESS.md §12.5.1 condition 4]
references: [BUILD_LOG.md 2026-06-08 session-10-close-retro entry, STUDIO_PROCESS.md §9]
tags: [process, handoff, generational-reboot, phase-boundary]
created: 2026-06-08
---

# Agent Handoffs — Phase 3 → Phase 4

> **Provenance note (honest disclosure).** The intended §12.5.1-condition-4 procedure was: each live gen-1 instance writes its own handoff before decommission. In practice, the runtime teardown (session restart at the lead's model upgrade, 2026-06-08) cleared the teammate roster BEFORE handoff requests could be delivered — all six SendMessage handoff requests returned "no agent addressable." The sections below are therefore **lead-reconstructed serializations from each instance's own words**: their session-10 close-retro reflections (received in full 2026-06-08, hours before teardown) plus their final [ready]/[ack] broadcasts. The retro reflections were structurally close to handoff format (carry-forwards + baselines + failure modes), so fidelity is high for the four heavy session-10 participants and lower for gp-sys/world-builder/ui-developer (reconstructed from BUILD_LOG records). The tacit layer is lost; that loss is the recorded cost of an unplanned teardown, and the lesson is codified below.
>
> **Process lesson for the next model upgrade:** request handoffs BEFORE the runtime restart that applies the upgrade. §12.5.1 condition 4 assumed reboot was something the project chooses; the runtime can also impose it. Treat any planned session restart as a handoff trigger.

---

## engine-architect (gen-1: `engine-architect-p3s2`, P3 s2 → s10)

**Open carry-forwards owned:**
- **Sim-cost optimization triad** (Phase 4+): spatial culling for AI scans (controllers iterate all units every AI tick), batched pathfinding (per-unit per-tick), per-team FSM batching. Bottleneck is sim work, NOT Godot frame budget — `Engine.physics_ticks_per_second = 1800` + `max_physics_steps_per_frame = 12` already maxes the engine path (headless_match_runner.gd ~:134).
- **Roster-as-knob flag**: 14-combat-unit starting roster is the per-tick cost driver; making it a `--headless-batch` preset flag unlocks fast iteration before the sim-opt wave ships.
- **8-autoload reset chain lift into MatchHarness**: scope NARROWED post-fix-up — the runner no longer needs it (process-per-match isolation); only the in-process reset-discipline test still exercises it.
- **Grace-period regression guard semantics**: `test_event_counters_are_deferred_not_aggregated` (probe branch, merged PR #54) FAILS when any future wave wires real event-summary counters — that failure is BY DESIGN the re-evaluation trigger for the ~30-tick throne-destruction grace-period question (loremaster's three concerns: NDJSON same-tick event ordering, mid-tick state-snapshot determinism, emit-flush-before-quit). Probe verdict was "empirically neutral TODAY because counters are hardcoded 0"; wiring counters re-opens it.

**Calibration baselines:** ~26 sim-ticks/wall-sec at 28-unit roster; 60K-tick match ≈ 33 wall-min; 50-match batch ≈ 28h (overnight-viable, not iteration-viable). The 4 originally-spec'd runner integration tests run in-process via `_test_skip_emit` + `_assemble_result_dict` seams (precedent: MatchHarness `_test_set_farr`).

**Lived failure modes (their own retro words, condensed):** (1) Godot `-s` script mode does NOT register autoloads — any script that names an autoload identifier fails to COMPILE, not just to run; always boot via main.tscn + cmdline-user-args gating. (2) The defensive-fallback-masking shape: `has_method` guard + wrong API name = silent zeros that pass every unit test; converted to hard-asserts at spawn (§9.M7 origin evidence). (3) Path-A-vs-Path-B reasoning discipline: count the actual reference sites before choosing a refactor path (61-reference count made Path A obviously cheaper). (4) The Step-5 deferral self-flag: "subprocess required" was confident-but-uninvestigated; a 15-min probe found the in-process seam (§9.B5 origin evidence).

---

## balance-engineer (gen-1: `balance-engineer-p3s3`, P3 s3 → s10)

**Open carry-forwards owned:**
- **AI_VS_AI_RESULT_FORMAT v1.1.0**: `turan.farr_x100_at_end` currently emits IRAN's Farr as proxy — semantically wrong, self-flagged; fix to `-1` until Turan Farr is separately tracked ("self-consistent-but-wrong data is worse than missing data — it produces confident wrong conclusions"). Also wanted: per-unit-type breakdown of `combat_units_alive_at_end` for RPS calibration.
- **balance.tres status tags**: 4 anchored / 17 calibrated / 3 placeholder as of session-9 follow-up; promotion requires batch data.
- **mine_node SSOT findings A+B**: reserves hardcoded 100 vs declared 1500; max_slots 1 vs mine_max_workers 2. Affordability table assumed the HARDCODED values (correct for current code) — re-run the §6 table after the SSOT fix lands.
- **Late-game-pressure design question**: duration data is INVALID as a pacing signal until late-game pressure exists; pre-registered in QUESTIONS_FOR_DESIGN.md.

**Calibration baselines:** Tuning-loop reading order: (1) outcome distribution + stalemate rate (if Iran wins 0%/100% the reference AI is degenerate, all else is noise; stalemate >30% = pacing dominates), (2) duration_ticks p50 vs 27,000-45,000 band, (3) iran_first_piyade_tick p95 vs 3600 (first probe), (4) only then RPS calibration. Income model: ~15 coin per 320 ticks at 5 workers / 3 mine slots (conservative); first Piyade ~tick 2070; grain caps Piyade production at 4 without a Mazra'eh step.

**Lived failure modes:** (1) The face-value trap: balance.tres declares; production code realizes; ALWAYS trace one consumption path per field claim (§9.L11.2 origin — both mine_node bugs were found this way and would have been missed by a back-of-envelope check). (2) Schema authorship: the brief's inline starting-proposal competes with the canonical spec doc for reader attention — the canonical doc must be SHA-pinned in dispatches (§9.D12 origin).

---

## qa-engineer (gen-1: `qa-engineer-p3s3`, P3 s3 → s10)

**Open carry-forwards owned:**
- **L7 lint** (§9.M7 mechanical enforcement): grep is trivial; the real work was the ~109-site triage, which the 2026-06-08 review pre-completed (~16 stale relics → hard-assert; ~25 genuine seams → allowlist; ~20 test-stub tolerance in unit states). Seed `tools/L7_allowlist.txt` from that classification.
- **test_batch_runner_subprocess_smoke.gd**: named at session-10, never built. Would have caught the `-s`-mode compile failure before the manual smoke did.
- **MatchHarness v2**: resets 5 of 13 resettable autoloads; spawn stubs return null since Phase 0; snapshot() reads dead fields. Written before FogSystem/TuranController/DummyIranController existed.
- **Determinism regression test**: still the Phase-0 empty-scenario stub — zero gameplay systems exercised. Highest-leverage test investment for Phase 4: snapshot-hash determinism over full real matches.
- **Fixture-drift sweep candidates**: MatchHarness signal shapes vs current runner reality; any test hand-crafting BalanceData-shaped dicts (schema changed at Wave 3A.6 +9 fields).

**Calibration baselines:** Suite ~42s at 1635 tests; 738 orphan nodes per run; 2 environment-dependent pendings silently skip real code paths; cold-start FALSE-GREEN — run_tests.sh exits 0 with zero tests run on an un-imported worktree (fix queued in session-11 hotfix wave).

**Lived failure modes:** (1) Fixture self-consistency ≠ correctness — wrong-name fixture + wrong-name assertions pass forever; the sibling real-data round-trip test (Flow 10 pattern, §9.M8) is the only structural antidote. (2) Schema-drift fix-ups must do the FULL field-by-field spec diff, not just the named drifts — the 4 bonus completeness fixes came from a 5-minute mechanical cross-check. (3) Value-semantic drift (plausible values contradicting spec prose, e.g., Turan workers=2 when spec says 0) is a distinct class field-name checks can't catch; N=2, watch for codification at N=3.

---

## shahnameh-loremaster (gen-1: `shahnameh-loremaster-p3s5`, P3 s5 → s10)

**Open carry-forwards owned:**
- **Anchor-category taxonomy**: 5/5 first instances shipped (civic-anchor / labor-organization / identity-bearing-institutional / sacral-emitter-divine-source / sovereignty-bearing-institutional). Tier-2/3 buildings (Qal'eh, Barghah, Yadgar, Dadgah) unclassified — each needs brief-time classification at its wave.
- **Dehqan-compression Iranist routing**: queued for Phase 4+; goes LIVE the moment user/lead identifies an Iranist or Shahnameh-khani contact (per 00_SHAHNAMEH_RESEARCH community-engagement guidance).
- **Campaign-mode revenge-arc anchors**: Iraj→Manuchehr and Siavoush→Kay Khosrow are the canonical narrative beats for "what happens after a throne falls" — they fire at Phase 5+ campaign-mode kickoff briefs, NOT match-scoped waves.
- **§9.J5 N=3 graduation watch** (side-quest research dispatch): N=2; one more wave-decoupled research dispatch graduates it.
- **Karavan-as-Turan-analogue thread**: flagged at Mazra'eh wave; relevant when Turan gets an economy (Phase 4+ asymmetric design).
- **Throne grace-period engineering note**: their sim-state-stabilization argument strengthened post-verdict; pinned by engine-architect's probe regression guard (see engine-architect section).

**Lived judgment patterns:** (1) Match-time vs narrative-time is the load-bearing distinction for any "when does X end culturally?" question — mechanics resolve at match time; continuation arcs live at campaign time; conflating them produces false tensions. (2) J4 honest-confidence-disclosure: claim → mechanism → confidence triple; HIGH only when the textual anchor is unambiguous. (3) Compression acceptability test: does the compression change what the player would FEEL is true about the source? (dehqan-to-Kayanian passed with acknowledgment; uncredited compressions fail). (4) §9.J6 conditional-fire (their own origination): brief-time fire on plumbing waves IFF a cultural-shape-question exists; performative participation produces performative reflection.

---

## gameplay-systems (gen-1: `gp-sys-p3s3`, P3 s3 → s9; reconstructed from BUILD_LOG, lower fidelity)

**Open carry-forwards owned (now includes TuranController + DummyIranController ownership, transferred from dormant ai-engineer):**
- Building production state machine: single-slot MVP queue; Phase-4 production queues are the designed extension point (`is_ready_to_produce` flips at Stage 2).
- IDropoffTarget protocol + `_local_stock_x100` seam on Mazra'eh: T&T forward-compat — activates if the design chat commits to Trade & Transport.
- BUG-G1 invariant: destructible entities subscribe to their LOCAL HealthComponent `health_zero` signal, never global `unit_health_zero` (unit_id namespace collision; root fix shipping in session-11 hotfix wave — read that diff before any new destructible entity).
- DummyIranController COMMAND_BUILD wiring (inherited): build-order checkpoints are log-only; real placement via the UnitState_Constructing flow is the data-validity wave's B3 deliverable.

**Lived failure modes (from BUILD_LOG):** BUG-C1 defensive-Dictionary.get silent-0 (their formative incident — now §9.M7); the cross-track diagnostic loop (reproduce → isolate layer → fix at the owning layer) ran successfully N=2; workspace-bleed vigilance (always `git status` before commit, pathspec-explicit staging per Pitfall #7).

---

## world-builder (gen-1: `world-builder-p3s2`, P3 s2 → s9; reconstructed from BUILD_LOG, lower fidelity)

**Open carry-forwards owned:**
- FogSystem rebuild cost: recomputes every dynamic source circle each tick (review optimization target #3); grid-resolution tradeoffs unexplored.
- Fertile-tile placement rejection: Phase-3 milestone that never shipped; permissive fallback waits on a TerrainSystem no wave owns — needs an owner decision at re-baseline.
- Navmesh explicit-pipeline invariants (Wave 1D): `parse_source_geometry_data(get_tree().root)` + synchronous `bake_from_source_geometry_data` from `Building._on_placement_complete`; L6 lint forbids the async variant. Do not regress to carve-only.
- Scene-UID convention: hand-authored stable scene UIDs (e.g., `uid://shahnameh_kargar_unit`) + path-based script refs — deliberate determinism-friendly convention; keep for new scenes.

**Lived failure modes (from BUILD_LOG):** BUG-D1 (FogSystem sim_phase wiring miss — wiring-path tests now canonical), BUG-D2 (team-id bounds rejecting TURAN — defensive-fallback-masking N=2), Pitfall #15 scene-script attachment regression tests.

---

## ui-developer (gen-1: `ui-developer-p3s3`, P3 s3 → s8; dormant since session 8, no live carry-forwards)

State at dormancy: ProductionPanel + build menu + tooltips + ghost-preview affordability shipped through Wave 3A.6/2B fix-waves. Known UI debt at decommission (from the 2026-06-08 review, not from the instance): UNIT_* translation keys missing for 8 of 9 unit types (selecting non-Kargar shows raw key); drag_overlay/drag_overlay_rect untested; §9.M6.2 backfill candidate on production_panel.gd remains opportunistic. Gen-2 spawns at the next UI wave with this paragraph + ARCHITECTURE.md §2 UI rows as onboarding.
