# Dune RTS — Research & Scoping Document

*Foundational research for a Dune-inspired real-time strategy game.*
*Last updated: 2026-04-22*

---

## 0. Your Stated Goals (refined through discussion)

- **Intent**: Commercial indie game → **revised to Path B: Dune-*inspired* original IP** (Funcom holds exclusive Dune game rights; see §1)
- **Source material**: Frank Herbert's original 6 books + Villeneuve 2021/2024 films (as inspiration, not direct adaptation)
- **Target**: PC desktop, initially aimed at SC2-style 3D, **refined to stylized 3D or 2.5D isometric** — photorealism confirmed non-essential
- **Team / budget**: Solo developer, no budget for assets
- **Programming preference**: Background in Go, Python, some C++. Prefers Go/Python ergonomics over heavy C++ work
- **Tooling preference**: **Claude Code as primary development environment** — wants maximum code-first workflow
- **Reference RTS games**: Age of Empires 2, Red Alert, StarCraft 2 — values systems and readability over fidelity

These refined goals change the engine recommendation substantially. The path is now cleaner than it was at the start of this document.

---

## 1. The IP Reality Check (Read This First)

**You cannot legally ship a commercial game called "Dune" or directly using Frank Herbert's named characters, factions, or unique invented terminology.** This is the single most important finding in this document.

### Who owns what

- **Frank Herbert's estate (Herbert Properties LLC)** owns the underlying literary rights.
- **Legendary Entertainment** holds the current film/TV rights (Villeneuve's adaptations).
- **Funcom** holds an **exclusive multi-year deal** with Legendary + Herbert Properties to make **three Dune video games**, signed in February 2019 for a six-year term. The first, *Dune: Awakening* (a survival MMO built in Unreal Engine 5), launched in June 2025. The remaining titles are in development.

Until Funcom's exclusivity lapses and a new licensee is chosen, **the Dune video game license is not commercially available at any price an indie could afford** — and even in a best case, negotiating a license as an unknown solo dev is not a realistic path.

### What this means practically

You have three honest options:

| Path | Description | Viability |
|---|---|---|
| **A. Licensed commercial Dune RTS** | Negotiate with Legendary / Funcom for an RTS sublicense | ❌ Effectively impossible as a solo indie. Closed door. |
| **B. Dune-inspired original IP** | Build the desert-ecology-spice-politics-giant-worms setting under a new name, with original factions, characters, and terminology that evoke but do not copy Dune | ✅ **Recommended.** Entirely legal, commercially releasable, creatively satisfying. |
| **C. Non-commercial fan project** | A free, open-source, non-monetized fan RTS using Dune names/lore directly | ⚠️ Legally risky (fan projects get C&Ds even when non-commercial) but the most "authentic Dune" experience. Incompatible with your "commercial indie game" goal. |

### What's protected vs. what's a genre trope

The good news: **the *atmosphere* of Dune is mostly genre tropes that can be reinterpreted freely.** You can absolutely make a game about:

- A harsh desert planet as the only source of a critical galactic resource
- Giant predatory sandworms that are attracted to rhythmic vibration
- Feuding aristocratic houses with private armies
- A secretive female religious order with uncanny mental abilities
- An emperor-versus-nobility political dynamic
- Stillsuits, personal shields, ornithopters — *as concepts* (though "stillsuit" and "ornithopter" are Herbert terms worth renaming)
- A messianic warrior figure emerging from a conquered tribe

The specific protected elements are **names and distinctive inventions**: "Arrakis," "Fremen," "House Atreides/Harkonnen/Corrino," "Bene Gesserit," "Mentat," "Paul Atreides," "Kwisatz Haderach," "Muad'Dib," "Shai-Hulud," "melange" (as a term — "spice" is a generic word), "Gom Jabbar," "the Voice," "Sardaukar," "Landsraad," "CHOAM," "Guild navigators."

**The pattern to emulate, not copy**: Warhammer 40,000 famously started as "Dune meets Judge Dredd meets Lord of the Rings" but built its own vocabulary. Frank Herbert himself stitched Dune from Islamic history, Zen Buddhism, ecological writing, and Lawrence of Arabia. You can do the same remix with a clear conscience.

### Recommendation

**Treat this as Path B from day one.** Design with Dune's themes and structures but build original IP. This is creatively liberating (you get to make design choices Frank Herbert didn't) and is the *only* path that is both commercially viable and legally safe.

The rest of this document assumes Path B.

---

## 2. Engine Research

### The candidates

| Engine | Language | Licensing | 3D RTS fit | Learning curve | Solo viability |
|---|---|---|---|---|---|
| **Unreal Engine 5** | C++ / Blueprints | 5% royalty after $1M gross, 3.5% via Epic Store, free below $1M | Excellent visuals out of the box (Nanite, Lumen). Mass Entity (ECS) system purpose-built for large crowds. | Steep. Massive engine. | Hard but done by solos. *Dune: Awakening* uses UE5 — validates the stack for desert/sci-fi. |
| **Unity 6** | C# | Seat-based Pro/Enterprise subscription above revenue thresholds. Runtime Fee cancelled (Jan 2026). Unity Personal free tier now covers up to **$200K revenue** (doubled from $100K) and splash screen is optional. | Strong. DOTS/ECS specifically built for thousands of entities. Largest RTS community/tutorials. | Moderate. C# is approachable. | Very viable. Classic solo-dev choice. |
| **Godot 4** | GDScript / C# / C++ | MIT — no royalties, no fees, no splash. | Improving rapidly, but 3D fidelity still lags and large-scale RTS performance is less battle-tested than Unity/Unreal. | Gentle. Lightweight, fast iteration. | Best for 2D RTS. Ambitious 3D RTS at SC2 unit counts = swimming upstream. |
| **O3DE (Amazon)** | C++ / Lua | Apache 2.0 | Technically capable, AAA-aimed | Steep, thin docs, small community | Not recommended for a solo first-time gamedev. |
| **Bevy** (Rust) | Rust | MIT/Apache | ECS-native, performant, but pre-1.0 | You'd be fighting the engine as much as building the game | Not recommended for a first game. |
| **Spring / Recoil** (open-source RTS engines) | Lua + C++ | GPL | Built for large-scale 3D RTS. Powers *Beyond All Reason* (10,000+ unit battles). | Opinionated — you work in its framework. | Interesting option but niche. See below. |

### Analysis for your specific situation

Your stated goal (**SC2 / C&C Generals-style 3D RTS**) means:
- Hundreds to low thousands of units on screen
- 3D camera with zoom + rotate
- Rich visual effects (spice storms, laser/projectile weapons, worm emergence)
- Skirmish AI and eventually multiplayer

Your constraints (**solo, no asset budget, strong C++/Python/systems background, first game**) mean:
- Free assets must exist in abundance for your chosen engine
- The engine must not require an art team to look decent (PBR defaults, good lighting out of the box)
- Your systems-programming strengths transfer best to engines with real programming APIs, not node graphs only

### Recommendation (revised): **Godot 4**

> *The original recommendation in this document was Unreal Engine 5, based only on the "3D SC2-style" visual target. After follow-up discussion surfaced three additional constraints — **preference to avoid heavy C++**, **Claude Code as primary dev environment**, and **photorealism not required** — Godot 4 became the clear winner. Unreal and Unity analysis retained below for completeness.*

**Why Godot 4 wins for your specific constraint set:**

1. **Text-file-native architecture.** GDScript files, scene files (`.tscn`), resource files (`.tres`), and project settings are all plain text. Claude Code can read and edit essentially every part of your project. No other mainstream engine gets this close to "code-first gamedev."
2. **GDScript feels like Python.** With your Python background, you'll read the language on day one. C# is also supported if you prefer it; GDExtension allows dropping to C++ for performance-critical code — but you almost certainly won't need it for an RTS at indie scale.
3. **Zero licensing cost, forever.** MIT license. No royalties, no revenue caps, no fees. If your game makes $10M, you owe the Godot Foundation $0. Simpler than Unity's $200K Personal cap or Unreal's $1M royalty threshold.
4. **Lightweight and fast iteration.** ~100MB engine. Instant startup. Rapid hot-reload. This matters for solo dev psychology — you launch the editor without it feeling like a commitment.
5. **Stylized 3D is a Godot strength.** Your reference RTS games (AoE2, Red Alert, SC2) are all stylized. Modern Godot 3D indie games (*Road to Vostok*, *Cassette Beasts*, *Tainted Grail: Conquest*) demonstrate that a well-art-directed Godot 3D game looks completely competitive in the stylized space.

**Accepted tradeoffs:**
- Photorealism ceiling lower than Unreal's. You've confirmed this doesn't matter.
- Large-scale 3D RTS performance (many thousands of units) is less battle-tested than Unity DOTS. Mitigation: target *hundreds* of units visible, which is enough for RTS feel — SC2 caps at 200 supply per player, and rendering 400 units total is well within Godot's range.
- Smaller premium asset marketplace than Fab/Unity Asset Store. Mitigation: you have no asset budget anyway, so you'd be leaning on CC0 sources regardless.

### Original analysis: why not Unreal 5 (primary) or Unity 6 (fallback)

**Why Unreal 5:**

1. **Your background is a strong match.** UE5 is C++ first. Your architect/systems instincts translate directly. You'll be uncomfortable in the editor the first two weeks and comfortable at home in the code the third week.
2. **Visuals "for free."** Lumen (global illumination) and Nanite (virtual geometry) make amateur scenes look professional. This is critical when you have no art budget — you'll be buying or using free assets and relying on lighting to sell them.
3. **Mass Entity** (Unreal's ECS-like framework introduced in recent versions) is designed precisely for RTS-scale crowds.
4. **Free asset ecosystem is real.** Fab (the merged Epic marketplace) has a rotating selection of free-for-the-month assets, and Quixel Megascans environments are free for UE users — enormously valuable for desert terrain, which is your entire setting.
5. **Royalty model is solo-friendly.** You pay nothing until your first $1M, and reduced to 3.5% if you launch on the Epic Store.
6. **Industry validation for the setting**: *Dune: Awakening* (Funcom, 2025) is built on UE5 — the engine has proven it can render desert + sandworms + sci-fi at scale.

**Why Unreal was demoted**: most Unreal gameplay logic lives in Blueprints (binary `.uasset` files), which Claude Code cannot read or edit. Even C++ Unreal projects typically have Blueprint subclasses extending C++ base classes. This makes Claude a much weaker collaborator in Unreal than in Godot. Also Unreal C++ has a learning curve that clashes with the "prefer Go/Python ergonomics" preference.

**Why Unity was demoted**: C# is great for Claude Code (pure text files). However, Unity scenes and prefabs expect editor-based composition — you'd still spend 30-40% of your time in the Unity Editor doing work Claude can't assist with. Unity remains a strong option if Godot's 3D proves limiting, but for the current constraint set Godot wins on fit.

**When to reconsider**: if, 6 months in, you're hitting Godot 3D performance limits that block your design, Unity with DOTS is the upgrade path. That's a later problem, not a starting problem.

**The Spring/Recoil option** deserves a footnote: if you become obsessed with simulating 10,000-unit battles specifically, *Beyond All Reason* demonstrates what Spring/Recoil can do. But you'd be signing up to learn a niche, GPL-licensed engine with a tiny community — not the right first project.

### Free asset sources (bookmark these)

- **Fab** (Epic's merged marketplace) — rotating free UE5 assets monthly, accessible directly from the Epic Games Launcher
- **Quixel Megascans on Fab** — **IMPORTANT update**: Megascans were free for everyone during late 2024, but Epic began charging again in 2025. The new **Megaplants** vegetation library (Nanite-compatible, for UE 5.7+) remains completely free. Budget for Megascans as a paid line item, or substitute with Poly Haven PBR textures
- **Kenney.nl** — CC0 3D assets, simple stylized, great for prototyping
- **OpenGameArt.org** — mixed quality, CC-licensed
- **Mixamo** — free rigged characters and animations (Adobe)
- **Sketchfab** — filter by CC0/CC-BY license
- **Itch.io asset packs** — many free or cheap indie packs
- **AmbientCG** / **Poly Haven** — free PBR textures and HDRIs

A solo no-budget 3D indie project in 2026 is more feasible than it was five years ago specifically because these resources exist. Use stylized art with strong lighting rather than attempting photorealism — this hides asset-quality variance.

---

## 3. Dune Lore — What Matters for RTS Design

This section distills the 6 Frank Herbert novels into the elements that are design-relevant for an RTS. Villeneuve film references are called out for *visual language* since that's what those films contribute (their plot is a subset of book 1).

### The core loop of Dune's universe (and why it's perfect for RTS)

Dune is a setting where:
1. **One scarce resource is the lynchpin of civilization** (melange / "the spice").
2. **That resource exists on one hostile planet** (Arrakis / "Dune").
3. **Extracting it is dangerous** because giant worms are attracted to vibration from harvesters.
4. **Political factions are locked in zero-sum competition** for extraction rights.
5. **Indigenous people** (Fremen) live in secret, know the desert, and represent a sleeping military power.
6. **Storms and environment** are themselves combat forces.

Every one of these is a natural RTS mechanic. The spice→worm→harvester triangle alone was the core resource loop of *Dune II* (1992), the game that **invented the modern RTS genre**. You are not inventing this translation; you are standing on 34 years of proof that it works.

### Books 1–6: what each contributes

| Book | Year | RTS-relevant contribution |
|---|---|---|
| **Dune** (1965) | — | Core setting. Houses Atreides vs. Harkonnen. Fremen. Worms. Spice. Shields. Stillsuits. Ornithopters. Mentats. Bene Gesserit. The feudal Imperium. **This is 90% of your design vocabulary.** |
| **Dune Messiah** (1969) | — | Smaller, political, post-victory. Lower RTS yield, but introduces Face Dancers (Tleilaxu shapeshifters) and Bene Tleilax as a faction. |
| **Children of Dune** (1976) | — | The Preacher, Leto II's transformation begins. Minor RTS material. |
| **God Emperor of Dune** (1981) | — | Leto II as worm-hybrid tyrant for 3,500 years. Ecology of Arrakis reversed (green Dune). Introduces Fish Speakers (all-female military). Thematically rich, mechanically niche. |
| **Heretics of Dune** (1984) | — | **Goldmine for RTS.** Introduces the Honored Matres (violent matriarchal faction from the Scattering), the Bene Gesserit as a proper military-adjacent power, and a resurgent Tleilaxu. Whole-galaxy geopolitics returns. |
| **Chapterhouse: Dune** (1985) | — | Continues the Bene Gesserit vs. Honored Matres war. The Scattering universe expansion. |

For an RTS, **~80% of your design material comes from Book 1**, with **Heretics + Chapterhouse providing excellent late-game/expansion factions**.

### Factions (the RTS-relevant ones, with design archetypes)

These are the Dune factions that would map to RTS factions — and what archetype they'd occupy. You'll rename these for IP reasons in your game, but the archetypes are fair game.

1. **House Atreides** — Balanced "honorable" faction. Strong infantry, elite heroes (Paul, Duncan Idaho, Gurney Halleck), advanced technology through alliances. Fits the "human / balanced" RTS slot (Terrans in SC2, GDI in C&C).

2. **House Harkonnen** — Brutal industrial faction. Cheap conscripts, heavy armor, fear-based bonuses, elite Sardaukar allies. Fits the "evil / zerg rush" slot (Zerg in SC2, Nod in C&C).

3. **Fremen** — Guerrilla faction. Weak early game but unmatched in desert terrain, can summon/ride worms, stealth mechanics, high late-game ceiling. The "asymmetric" faction — no clear SC2 analogue, which makes them *distinctive*.

4. **Sardaukar / Imperial forces** — Elite professional military. Small numbers, extreme per-unit power. Often a fourth faction or an NPC hostile power.

5. **Bene Gesserit** — Intrigue/subterfuge faction. Would work as a non-standard RTS faction built around conversion, influence, and support rather than direct combat. Difficult but innovative design.

6. **Spacing Guild** — Not really an army. Better as an economic/logistics meta-system (transport, off-world trade) than a playable faction.

7. **Bene Tleilax** — Biotech/shapeshifter faction. Clone armies, Face Dancer infiltrators, heretical science. Good 5th/6th faction for expansion.

8. **Honored Matres** (Heretics+) — Fast, aggressive, seductive mind-control matriarchy. Excellent "exotic" faction for post-launch DLC.

**For MVP**, pick three factions with maximally distinct playstyles. The classic C&C 2-faction model (noble house vs. evil house) plus **Fremen as the wildcard asymmetric faction** is likely your sweet spot.

### Core gameplay mechanics drawn from the setting

These are the "genre tropes from Dune" that should drive your gameplay. None are legally protected — they're all fair game as long as you rename specifics.

| Mechanic | How it works | Design value |
|---|---|---|
| **Spice extraction with worm risk** | Harvesters collect spice but emit vibration. Worms appear after a timer. Must call a carryall (airlift) to extract before worm arrives. | Risk/reward core loop. Creates map-wide tension without enemy action. |
| **Desert terrain / no-go zones** | Open desert = worm territory; rocky terrain = safe. Armies must route around or accept worm risk. | Terrain-as-combatant. Creates real map geography, not just "forests block line of sight." |
| **Personal shields** | Slow-moving projectiles blocked; fast weapons pass through. Lasers + shields = nuclear detonation. | Rock-paper-scissors with consequences. Forces decisions between shielded melee units and ranged. |
| **Ornithopters** | Air units that are cheap, fast, fragile. Primary scouts and harassers. | Vertical map dimension. Air is central to desert warfare. |
| **Sandworm riding** (Fremen) | Advanced Fremen tech: mount worms as mobile super-units. | Late-game faction-defining power. Risky to balance — that's the design challenge. |
| **Spice storms / Coriolis storms** | Periodic massive storms that sweep the map, damaging exposed units. Visual spectacle + forces base placement into rocky terrain. | Environmental pressure. Forces player to plan around a clock, not just opponent. |
| **Stillsuit / water economy** | Optional: water as a secondary resource that gates unit sustain in desert. | Adds depth without much extra UI if done right. |
| **Mentats / prescient heroes** | Hero units with perception/prediction abilities (see through fog longer, predict enemy moves briefly). | High-value hero gameplay. |
| **Heighliners / strategic transport** | Meta-layer: deploying armies across multiple maps via off-world transport (campaign level). | Good for campaign structure, skip for multiplayer MVP. |

### Villeneuve film visual language (what to study, not copy)

Villeneuve's 2021/2024 films contribute the **visual vocabulary** that will most resonate with modern audiences:

- **Brutalist architecture**: massive, monolithic, concrete-like structures dwarfing humans. Use this for base buildings — it reads as "serious sci-fi" instantly.
- **Dragonfly-style ornithopters**: the wing-beat mechanism is a striking silhouette. Your air unit should have a distinctive silhouette; study theirs, design your own.
- **Sardaukar aesthetic**: black-clad, inhuman, ritualistic. The "elite heavy infantry" look.
- **Desert color palette**: warm ochres, harsh white midday light, deep purple-blue nights. Your game's lighting should live in this space.
- **Scale**: Villeneuve's Dune conveys scale through sparse composition — vast flats, tiny humans, monstrous worms. Your camera and unit scale should respect this.
- **Sound as identity**: Hans Zimmer's score uses unusual vocals and bagpipe-like drones. Original IP means you need original sound identity — but the *principle* (unusual, otherworldly, non-orchestral) is the reference.

Ignore the specific faces and costume details; steal the mood and composition principles.

---

## 4. Scope Recommendations for a Solo Dev

This is where I'll be most direct. **An SC2-scale 3D RTS is among the hardest things a solo dev can attempt.** SC2 took Blizzard ~7 years and hundreds of developers. *Beyond All Reason* has a community of dozens contributing over a decade. Your ambition here is real; the timeline must match.

### Realistic scope tiers

**Tier 0: Technical prototype (target: 2-3 months)**
Goal: prove to yourself you can ship *anything* in Unreal.
- Flat terrain, one unit type, RTS camera, click-to-move, basic pathfinding
- No art; use engine primitives
- No AI beyond "walk to target"
- **Ship this to itch.io as a free download.** Real deadline forces completion.

**Tier 1: Vertical slice (target: 6-12 months after Tier 0)**
Goal: one complete skirmish experience that demonstrates the whole design.
- One playable faction, one enemy faction (AI only)
- One map: desert with rocky outcroppings, 1-2 spice fields
- The core loop: build base → harvest spice → produce army → defeat enemy
- Worm mechanic working (this is your signature mechanic — it must feel great)
- ~6-10 unit types per side
- Bought or free assets, tied together by strong lighting
- **This is the artifact you show publishers, Kickstarter, or Steam wishlist campaigns.**

**Tier 2: Demo release (target: 6-12 months after Tier 1)**
Goal: a Steam "Next Fest" demo.
- 2-3 factions
- 3-5 skirmish maps
- Functional campaign structure (3-5 missions)
- Refined UI, audio, menus, saves/loads
- **Get a free Steam page up the day you start this tier.** Wishlist count is your progress bar.

**Tier 3: Full release (target: 1-2 years after Tier 2)**
- 3 factions balanced to competitive standard
- ~10 missions, full campaign with narrative
- Skirmish AI with 2-3 difficulty levels
- Multiplayer (this alone can double your timeline; consider scoping it out of v1.0)
- Steam launch

**Total realistic timeline for a solo, nights-and-weekends dev: 4-6 years.** Working full-time on it: 2.5-4 years. This is not a discouragement — this is the shape of the work. Many solo indies have done exactly this (see *Manor Lords*, *Dwarf Fortress*, *Kenshi*, *Stonehearth*). None of them was the developer's first game.

### The critical honesty

**This should probably not be your first game.** Consider making a smaller first project to earn your engine proficiency — a single-faction, single-map RTS-tutorial-level game, shipped to itch.io in 3 months. Then start the Dune-inspired game with engine fluency already in hand. Every solo-dev success story starts with at least one abandoned or tiny first project. Plan for that explicitly instead of hitting it by surprise at month 10 of your dream project.

---

## 5. Recommended Next Steps (in order)

1. **Commit to Path B**: accept that this is a Dune-*inspired* original-IP game. Start sketching a setting bible — a planet name, faction names, the invented terminology for spice/worms/houses. The act of naming things is the act of taking ownership.
2. **Install Godot 4** (~100MB download, no account required) and complete the **official "Your First 2D Game" and "Your First 3D Game"** tutorials on the Godot docs site. Expect ~a weekend. The goal is editor fluency.
3. **Decide between 2.5D isometric and stylized 3D** for the MVP. Given solo + first game, the pragmatic choice is 2.5D isometric with the option to evolve later. Don't over-commit to 3D on day one.
4. **Build a throwaway mini-RTS** (not Dune-related): one unit type, click-to-move, one enemy, a basic resource to collect. Follow a Godot RTS tutorial (GDQuest, Miziziziz, or the official demos). Target 2-4 weeks. The goal is engine fluency, not a keepable codebase.
5. **Then** start Tier 0 of the real project (see §4). Set up a private Steam page for wishlist collection at Tier 1.
6. Throughout: keep a **design bible** (one markdown file per faction, mechanic, and lore element) in this repo. Your architect instincts will reward clear documentation more than most solo devs' do — and Claude Code works best against well-documented intent.

---

## 6. Open Questions I Need From You

Before we go deeper, a few follow-ups that will sharpen the plan:

- **Are you willing to commit to Path B (Dune-inspired original IP)?** If not, we need a different conversation about scope.
- **Full-time or nights-and-weekends?** Changes the timeline by ~2-3x.
- **Do you want to start with a tiny throwaway first game**, or go directly into the Dune project accepting a slower ramp?
- **Multiplayer in v1.0 — yes or cut?** This is the single biggest scope lever.
- **Any hard deadline?** (Some people have self-imposed "ship by 40th birthday" type deadlines; these reshape scope significantly.)

Your answers to these drive everything downstream — including whether the next document in this repo is a *Setting Bible* (naming the world) or a *Technical Architecture* (engine setup and repo structure).

---

*End of research document. Everything in here is version 1. Assumptions should be challenged as we learn more.*
