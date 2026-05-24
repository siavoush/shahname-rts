---
title: Shahnameh Economy Research — Cross-check of the Trade & Transport thesis
type: research
status: living
version: 1.0.0
owner: shahnameh-loremaster
summary: Loremaster cross-check of the Phase-4+ Trade & Transport economy thesis (per QUESTIONS_FOR_DESIGN.md 2026-05-24) against Ferdowsi's Shahnameh + pre-Islamic Iranian administrative-historical record. Six research questions on faction asymmetry, depot→caravan→Throne flow accuracy, raid-as-canon, supply-line decisiveness, escort tropes, and cultural anti-patterns. Findings include serious flags on "dehqan-Throne reciprocity" framing being potentially Islamic-period-read-backward + supply-line-decisiveness being weaker in epic than design thesis assumes. Honest J4 split per question. Net verdict: thesis fits well with two material refinements documented in §7.
audience: all
read_when: phase-4-trade-and-transport-design-chat, economy-mechanic-design-questions, faction-asymmetry-questions
prerequisites: [00_SHAHNAMEH_RESEARCH.md, QUESTIONS_FOR_DESIGN.md, docs/ANCHOR_CATEGORY_TAXONOMY.md]
ssot_for:
  - Shahnameh cross-check findings on the Trade & Transport economy thesis
  - faction-asymmetry empirical grounding (Iran settled-tribute / Turan nomadic-raid)
  - canonical caravan-raiding episodes in the epic (Iran-Turan border raids; Esfandiyar campaigns; Siavoush-revenge wars)
  - supply-line-decisiveness findings (where present in epic; where absent)
  - "dehqan-Throne reciprocity" framing audit — Islamic-period-read-backward flag
  - bidirectional-flow corrective (royal largesse + counter-flows from treasury)
references: [00_SHAHNAMEH_RESEARCH.md, 01_CORE_MECHANICS.md, QUESTIONS_FOR_DESIGN.md, docs/ANCHOR_CATEGORY_TAXONOMY.md, MANIFESTO.md]
tags: [research, economy, trade-and-transport, faction-asymmetry, cultural-authenticity, loremaster]
created: 2026-05-25
last_updated: 2026-05-25
---

# Shahnameh Economy Research — Cross-check of the Trade & Transport thesis

## 0. What this doc is, and what it is not

**This doc cross-checks the Phase-4+ "Trade & Transport" economy thesis** (per `QUESTIONS_FOR_DESIGN.md` 2026-05-24 entry, captured in the lead's dispatch as: economy IS the contest; workers→local depot→caravan→Throne flow; escort automation; settlements+armies demand upkeep; emergent Iran-Turan asymmetry) against:

- **Ferdowsi's Shahnameh** (the project's primary source per `MANIFESTO.md` + `CLAUDE.md`)
- **Pre-Islamic Iranian administrative-historical record** (Achaemenid → Parthian → Sasanian periods that the Shahnameh draws semi-historical content from; epic post-dates the political reality it narrates, often by centuries)
- **Project-internal cultural-note framing** that has accumulated across Waves 1B (Ma'dan) through 3-Throne (sovereignty-bearing institution) and continues in Wave 3-LocalDropoffs (currently in flight)

**Six research questions** answered per the dispatch. Each gets: framing / Shahnameh evidence / scholarly grounding where applicable / verdict on the design-thesis implication / refinement candidates if any.

**This doc is NOT:**
- Design proposal. Findings route to design-chat; the chat decides what (if anything) lands as a `01_CORE_MECHANICS.md` Phase-4+ commitment.
- An audit of every project cultural-note for backward-compat with the findings. §7 surfaces consequences; the actual edits (if any) ship as follow-up work the design-chat ratifies.
- A definitive academic treatment. I am a project-loremaster reading the epic + commonly-attested historical sources, NOT an Iranist scholar. Where my confidence is lower (Achaemenid administrative detail; Islamic-period vs Kayanian-age cultural concept dating), I flag it explicitly.

**Honest J4 split applied per question** — distinguishing claims grounded in Shahnameh-textual evidence (loremaster lane) from claims grounded in historical-Iranist consensus (citation-density-lower, marked as such) from claims that are loremaster interpretation (marked as opinion).

**Net verdict (skip to §6 + §7 for the synthesis if reading in order is too much):** the thesis fits the Shahnameh well, with **two material refinements** that should land before the Phase-4+ implementation locks. (1) The "dehqan-Throne reciprocity" framing currently saturating project cultural-notes is **partially anachronistic** — the term *dehqan* in its Shahnameh-era sense maps onto landed-cultivator-custodian, but the *tribute-to-takht* reading is mostly Sasanian-and-later administrative reality rather than Kayanian-heroic-age epic content. (2) **Supply-line-decisiveness is weaker in the epic than the design thesis assumes** — the Shahnameh's battle-narrative is dominated by champion-combat + army-meets-on-field shapes; the supply-line vulnerability the design wants to ship is more historically-grounded than epically-grounded. Both refinements are absorbable; neither breaks the thesis.

---

## 1. Q1 — Is "settled-agricultural-tribute Iran vs nomadic-raid-spoils Turan" actually the Shahnameh's lived economic-political structure?

### The framing claim

The design thesis (per the dispatch + `QUESTIONS_FOR_DESIGN.md` 2026-05-24 table) treats Iran as *settled, agricultural, dehqan-tribute-to-takht* and Turan as *nomadic, raid-economy, oath-of-loyalty-to-named-rulers*. Lead asked: is this Shahnameh-grounded, or am I projecting a modern reading?

### Shahnameh-textual evidence

**The asymmetry IS textually grounded.** Three load-bearing anchors:

**(a) The Fereydun tripartite division (`00_SHAHNAMEH_RESEARCH.md` §1 line 91).** Fereydun divides the world among Salm (Rum / west), Tur (Turan / east-and-north), and Iraj (Iran / center). The division is *geographic + cultural*: Iran gets the settled plateau, Turan gets the steppe-and-mountain-frontier territories north and east of the Oxus / Amu Darya. Salm and Tur murder Iraj out of jealousy over the inheritance. **The Iran-Turan economic asymmetry is the structural condition of the heroic-age conflict from the moment Fereydun draws the borders.** Iran inherits the agricultural plateau; Turan inherits the steppe. Each people's economic mode follows their land — and the conflict between them is endlessly about who controls the frontier between settled and steppe.

**(b) Iran as "settled, agrarian, kingly" — already framed at `00_SHAHNAMEH_RESEARCH.md` §3 lines 161-165.** The project's primary research doc explicitly characterizes Iran as "settled, agrarian, kingly. Centered on the Iranian plateau. Champion-driven warfare led by heroic pahlavans. Persian cavalry, heavy armored infantry, legendary archers (the Parthian shot is real military history), war elephants (Sasanian)." Turan is "nomadic-steppe culture. Swift cavalry, horse archers, raiders. Broader, looser armies built on mobility." This is the project's source-of-truth on the asymmetry, and Ferdowsi's own framing aligns: settled Iran, steppe Turan.

**(c) The Pishdadian agrarian-founding sequence as Iran-side anchor (§1 lines 86-88).** Hushang discovers fire; Tahmuras subdues the divs and forces them to teach writing, weaving, and craft; Jamshid invents metalwork + founds the social classes including the dehqan. **These foundings are explicitly Iran-side civilizational acts.** The epic does NOT credit equivalent agrarian-foundings to Turan; Turan inherits a different (nomadic-pastoral) social mode the epic treats as the *other* relative to Iran's settled core.

### Where the asymmetry is more nuanced than a clean Iran-versus-Turan binary

**(a) Turan does have named cities + courts + thrones.** Afrasiyab's takht is a *named, located royal seat* (per Throne wave brief-time review, sovereignty-bearing institution applies cross-faction; same anchor-shape, different cultural register). The Shahnameh does NOT depict Turan as pure-nomadic-without-fixed-anchors — the Turanian kings have palaces, courts, named officials (Piran-Viseh as wise counselor at Afrasiyab's court, `00_SHAHNAMEH_RESEARCH.md` §1 line 116). **The asymmetry is Iran-MORE-settled vs Turan-MORE-mobile, not pure-settled vs pure-nomadic.**

**(b) Iran also raids Turan canonically.** The epic's Iran-Turan wars are explicitly bidirectional (see Q3 below for episode-level evidence). Manuchehr invades Turan to avenge Iraj. Kay Khosrow's army marches deep into Turanian territory to finish Afrasiyab. Rostam crosses into Turan in his campaigns. **The "Turan raids Iran" framing alone is incomplete and risks turning Turan into the only aggressor — which `00_SHAHNAMEH_RESEARCH.md` §307 explicitly warns against** ("Design Turan as worthy rivals, not cartoon villains. Reserve cartoon villainy for the divs and Zahhak").

**(c) Both factions practice tribute.** *Baj* (tribute) flows in the epic from defeated parties to victors regardless of faction-identity. Manuchehr collects baj from Salm and Tur's territories after avenging Iraj. Afrasiyab collects baj from subject peoples within his realm. **Tribute is not an Iran-exclusive economic primitive; it's a universal ancient-Iranian-cultural-sphere institution.** The Iran-Turan asymmetry is in *whether tribute flows are the PRIMARY economic mode (Turan's leading-hypothesis) or one mode alongside agrarian production (Iran's leading-hypothesis)* — not in tribute-vs-no-tribute.

### Scholarly grounding (lower citation-density; flagging where I'm extrapolating)

The Iran-Turan duality in the Shahnameh tracks (loosely, with poetic compression) onto the **Iranian-plateau-settled / Central-Asian-steppe-nomadic** civilizational interface that has been a real geopolitical structure across the Achaemenid → Parthian → Sasanian periods. Greek sources (Herodotus on the Persian-Scythian frontier; later Greco-Roman sources on Parthian-vs-steppe-confederation dynamics) attest the structural reality across multiple periods, even as the specific peoples on either side change. The Shahnameh poetically generalizes this into the Iran-Turan binary; Ferdowsi conflates Scythian, Hephthalite, and Turkic confederations under "Turan" across the epic's chronological span.

**Honest J4 flag:** I am citing this scholarly consensus from general Iranist + ancient-history reading, not from a specific source I can name. If lead/user want this nailed down, recommended reading: Touraj Daryaee's *Sasanian Persia: The Rise and Fall of an Empire* + Richard N. Frye's *The Heritage of Persia*. Both treat the Iran-Turan / settled-steppe interface as a real historical structure.

### Verdict on the design thesis

**The asymmetry framing is Shahnameh-grounded and culturally honest, with the bidirectional-raiding + Turan-has-named-courts refinements above.** The thesis's "Iran = settled-tribute, Turan = nomadic-raid" maps onto the epic's structural dichotomy. Two refinements needed:

1. **Bidirectional raiding is canonical.** The design's "Turan raids Iran's caravans" should be paired with "Iran raids Turan's mobile-camps and herd-routes" as the mirror mechanic. If only one direction ships at first, design-chat should explicitly note "Iran-side raid mechanic is deferred, not absent" rather than implying Turan is the only aggressor.
2. **Turan ALSO has fixed anchors (royal seats, courts).** The structural-mismatch hypothesis for other anchor-categories (Mazra'eh / Ma'dan / Sarbaz-khaneh / Atashkadeh) holds, BUT the Throne case (per the v1.1.0 taxonomy doc §5 NEAR-SYMMETRY exception I shipped at `d59b771`) is precedent that *some* Iran-side building shapes DO clone to Turan. Future Turan-side building design should treat each anchor-category case-by-case.

### Refinement candidates flagged

- The "Iran-Turan asymmetry" framing in project cultural-notes is currently saturating toward "settled-good-Iran vs steppe-other-Turan" — that's a drift to watch. The epic's Turan has dignity, named characters with depth (Piran-Viseh is one of the epic's most sympathetic figures; Forud, Afrasiyab's grandson via Siavoush, is tragic; Aghrirath defies Tur and Salm to spare Iraj). When Turan-side building work eventually ships, cultural-notes should honor this dignity rather than treating Turan as the negative-of-Iran.

---

## 2. Q2 — Is the local-depot → caravan → Throne flow historically accurate for pre-Islamic Iran?

### The framing claim

The thesis depicts wealth as a multi-hop flow: workers extract → local depot accumulates → caravan transports → Throne treasury receives. Lead asked: is this historically grounded for Achaemenid / Parthian / Sasanian Iran (the periods the Shahnameh draws semi-historical content from)?

### Historical-Iranist grounding (citation-density: medium-high, where applicable)

**The multi-hop flow is well-attested across all three pre-Islamic Iranian imperial periods.** Specific institutional anchors:

**(a) The Achaemenid Royal Road (~480 BCE forward).** The 2,500-km road from Susa to Sardis, with way-stations (*chapar-khaneh*) every ~25 km, supported by the *chapar* courier system — fresh horses + relay riders. Herodotus describes it; the Persepolis Fortification Tablets (administrative records from the Achaemenid heartland) attest the system's operation. **The infrastructure for inter-province transport of administrative wealth (and people, messages, soldiers) was a real Achaemenid institutional achievement, not a poetic invention.**

**(b) The satrapy tribute system.** The 23 Achaemenid satrapies each contributed annual tribute (*baji*) to the imperial center, with the tribute composition tied to the satrapy's productive specialization (gold from Bactria, horses from Media, silver from Lydia, etc.). Persepolis reliefs depict tribute-bearers from each satrapy in a famous procession scene. **Tribute flowed from local administrative centers UP to the imperial seat through caravan-transport infrastructure.** This is the historical reality the design's flow-model maps onto.

**(c) The Sasanian *kharaj* (land-tax) system.** Continued the Achaemenid model with refinements — land registry, tax-assessment by surveyors, collection by satrap-equivalent officials (*marzbans*), transport to the royal treasury (*ganj*). The dehqan class emerges as the local-administrative-cultivator-custodians who manage the chain at the village/region level. **The "wealth flows TO the seat via multi-hop infrastructure" pattern is solidly Sasanian.**

**(d) Caravan transport was the standard logistical mode** across all three periods for moving high-value administrative wealth (silver, gold, fine goods) between regions. Caravans were typically organized by professional caravan-masters, often with armed escorts for high-value loads (more on this in Q5).

### Where the historical reality is more nuanced than the simple flow-diagram

**(a) Local accumulation was NOT primarily at the production site.** In the Achaemenid system, harvested grain was typically stored at the *village-level granary* (not at the individual farmstead) and at *satrapal-capital granaries* before any onward flow to the imperial center. The dehqan as *village-level administrator* makes sense here — he's the layer between the cultivator (the actual farmer) and the satrap (the regional administrator). **The project's current model collapses these layers** (Mazra'eh = farm = local depot, all in one building) for RTS-tractability reasons. This is a defensible compression but worth knowing it's a compression.

**(b) The caravan-attackability claim is partially anachronistic.** During the high-functioning periods of all three imperial systems, the imperial road infrastructure was *well-protected*: military garrisons at way-stations, official courier-and-escort logistics, the political-control of the routes by the imperial center. Caravans were robust-by-default during stable periods; raiding was a *frontier* and *imperial-decline* phenomenon, not the normal-operating-condition. **The epic, however, narrates moments of imperial-stress + frontier-conflict** (Iran-Turan border wars; the Siavoush-revenge generation; Bahman's punitive campaigns); these are the periods where caravan-raiding becomes narratively prominent. So:
- **Normal-historical-period:** caravans robust, escorts well-funded, raid is exceptional.
- **Epic-narrated period (Kayanian heroic age + Sasanian-era retold):** caravans vulnerable because the empire is at war with Turan / divs / external pressures; raid is a *frontier* gameplay loop.

The design thesis's "caravans are attackable / lossable" mechanic is consistent with the *epic-narrated* state, not the *imperial-administrative* state. **For the project's RTS framing — heroic-age conflict between Iran and Turan — caravan-attackability IS the canonical state**, because the project is set during the conflict-mode of the epic, not the peacetime-administrative-mode.

### Verdict on the design thesis

**Historically accurate for the Shahnameh-era settings, with one design implication:**

- The depot→caravan→throne flow IS well-grounded across Achaemenid → Parthian → Sasanian periods.
- The caravan-as-attackable framing fits the EPIC's narrative mode (war between Iran and Turan), even though it overstates the historical-administrative reality of normal imperial-operation.
- **The local-depot-as-village-level-administrative-node (rather than as-farmstead) layer is collapsed in the current project model**; that's a defensible RTS-tractability choice but worth surfacing if the design chat wants to honor the layered administrative reality more precisely.

### Refinement candidates flagged

- Phase-4+ design could optionally introduce a *village* or *satrapy* intermediate layer between local depot and Throne; this would be more historically faithful but adds mechanical complexity. Likely not worth shipping unless the design wants to surface the dehqan-as-administrator-not-just-cultivator dimension as a distinct game mechanic.
- The "stable empire = robust caravans; war = vulnerable caravans" historical distinction maps onto a potential *campaign-progression* dimension: early game could have low-raid frequency (stable empire); late game escalates to high-raid (war-mode). Not a current design proposal; flagging as a refinement candidate the design chat may want to consider.

---

## 3. Q3 — Caravan-raiding as canonical Shahnameh activity

### The framing claim

The thesis ships caravan-raiding as a primary gameplay loop. Lead asked: are there specific episodes? If we make caravan-raiding a load-bearing mechanic, what episodes can it cite as canonical precedent?

### Shahnameh-textual evidence

**Caravan-raiding-as-such is less directly attested than supply-line-disruption-and-frontier-raiding more broadly, but the broader category is heavily canonical.** Specific episodes:

**(a) Manuchehr's punitive war against Salm and Tur (Pishdadian era).** Iraj's avenger crosses the frontier to make war on his uncles, collecting tribute and treasure after defeating them. The campaign involves cutting off supply / lines of retreat. While not a "raid the caravan" episode in the modern-RTS-mechanic sense, it establishes the Iran-as-active-aggressor-too pattern early in the epic.

**(b) The Iran-Turan border wars across the Kayanian era.** The Oxus / Amu Darya / Jeyhun river is the canonical frontier zone (see `00_SHAHNAMEH_RESEARCH.md` §1 line 120 — Siavoush's exile-to-Turan crosses this frontier; Afrasiyab's territory begins beyond it). Most of the heroic-age conflict happens at this frontier. Skirmishes, raids, ambushes, intercepting movement across the river are the *primary military mode* in this zone — NOT pitched battles. **The epic's tactical reality at the frontier is heavy on raiding/skirmishing, light on Western-medieval-style siege-and-pitched-battle.**

**(c) Esfandiyar's campaigns (`00_SHAHNAMEH_RESEARCH.md` §1 line 111).** Esfandiyar conducts a series of campaigns including conversion-by-sword campaigns and the seven-trial journey (Esfandiyar's own *Haft Khan*, parallel to Rostam's). These campaigns involve frontier raiding, supply-cutting, and ambush-style warfare — the kind of tactical content the design's caravan-raid mechanic would surface.

**(d) Bizhan-and-Manizheh (a major Kayanian-era arc).** Bizhan, an Iranian hero, crosses into Turan and is imprisoned by Afrasiyab. Rostam mounts a rescue mission — disguising himself as a *caravan-leader* traveling with merchant-disguise. **This is the closest direct epic-canonical reference to caravan-as-cover-for-military-operation, with Rostam exploiting the caravan-trope tactically.** The episode validates the caravan-as-a-thing-that-exists-and-moves-across-the-Iran-Turan-frontier framing the design wants to ship.

**(e) Afrasiyab's raid tactics broadly.** Afrasiyab is depicted across the epic as a king who *raids and withdraws*, not as a king who fights symmetric pitched battles by preference. His campaigns against Iran often involve incursions, retreats, secondary fronts, allies-of-convenience. The epic frames this as part of his cunning (and ultimately his moral failing — see `00_SHAHNAMEH_RESEARCH.md` §1 line 115: "rules for centuries"; §307 "cunning and cruel, but he is a king, not a monster"). **The "Turan raids Iran" gameplay loop has explicit textual precedent in Afrasiyab's tactical signature.**

**(f) Forud's tragedy** — Forud is the grandson of Siavoush via the Turanian line, raised at his mother's mountain stronghold on the Iran-Turan frontier. When the Iranian army marches against Turan, Forud and his small force ambush them from his fortified position before identities are clarified; he is killed in the resulting battle. **This is an episode of frontier-raiding from a fixed defensive position** — closer to the project's "settled defender raids the invader" pattern than to caravan-interception, but it grounds the bidirectionality of raid-warfare at the frontier.

### Where caravan-raiding is more *connoted* than *named-and-narrated*

The epic does not, to my reading, contain an episode that is literally "X intercepted a tribute caravan, captured it, and that determined the outcome of the war." The closest analogues are:
- **Bizhan-Manizheh** (caravan-as-cover, not caravan-as-target).
- **Frontier-raiding broadly** (interception of supply lines as part of the war tactics but not the load-bearing narrative beat).
- **The strategic-position-and-supply-line dimension** is *implied* in many Iran-Turan war episodes (armies cross rivers; supply chains stretch; defenders ambush from terrain) but not centrally NARRATED as the decisive factor.

### Verdict on the design thesis

**Caravan-raiding fits the epic's frontier-tactical-reality cleanly, with explicit precedent in Bizhan-Manizheh + Afrasiyab's tactical signature + the broader Iran-Turan frontier-raid pattern.** It is NOT, however, a primary epic-narrated decision-point in any specific Kayanian-era war the way (say) a champion duel or a hero's death is. **Design implication:** the mechanic is culturally honest as a *background economic-tactical loop*, but lead/user should NOT expect it to carry the same narrative-weight as champion-combat or hero-death moments. Caravan-raids in the game should be the *texture* of the war, not the *climax* of the campaign.

### Refinement candidates flagged

- **Bizhan-Manizheh as Phase-4+ campaign-mission candidate.** The "Rostam infiltrates Turan disguised as a caravan-master" episode is mechanically rich — it surfaces caravans-as-game-objects in a hero-mission context. If the design wants to anchor caravan-mechanics narratively, this episode is the strongest single anchor.
- **Frontier-zone visualization.** The Oxus/Amu Darya as the *canonical conflict zone* — maps should locate Iran-Turan border zones with terrain features (river crossings, mountain passes) that naturally channel caravan traffic and create raid-ambush opportunities. The map's geography should encode the epic's tactical reality.

---

## 4. Q4 — Settlement & army upkeep / supply-line decisiveness

### The framing claim

The thesis ships settlements + armies as requiring upkeep — bigger army → more upkeep → more dependent on flow → more raidable. Lead asked: does the Shahnameh actually show supply-line-vulnerability as decisive, or is the epic's battle-narrative more "two armies meet on a field"?

### This is where I find the most friction with the design thesis — honest answer:

**The Shahnameh's battle-narrative is overwhelmingly champion-combat + army-meets-on-field. Supply-line-vulnerability as the DECISIVE factor in named battles is rare.**

### Shahnameh-textual evidence (such as it is)

**What the epic foregrounds:**

- **Champion combat (*mard-o-mard*).** Two warriors meet, fight to the death, the army of the loser is demoralized. Sohrab vs Rostam. Esfandiyar vs Rostam. Rostam vs the White Div. This is the DECISIVE-battle shape across most of the epic. The army surrounds the duel; the duel determines the outcome.
- **Army-meets-on-field pitched battle.** Manuchehr's army vs Salm-and-Tur's. The Iranian army's marches against Afrasiyab. The final battle that ends Afrasiyab. The shape is roughly: armies muster, they meet at a location named in the epic, the battle is described with poetic compression (often just "they fought; X prevailed because of [hero / divine intervention / numerical advantage]"). **Supply lines are not narratively foregrounded as the deciding factor in these battles.**
- **Divine intervention + Farr.** Battles turn because the Simurgh aids one side; because Farr-ī Yazdān has departed the unjust king; because a hero's special gift activates. **Theological-political legitimacy is the load-bearing decision-factor, not material supply.**

**What the epic does NOT foreground:**

- **Logistics-decisive battles.** I cannot cite a Kayanian-era Iran-Turan battle where the explicit narrative beat is "X's army starved because their supply line was cut and that's why they lost." The epic does not narrate this kind of battle.
- **Sustained-war attrition.** Wars in the Shahnameh tend to be punctuated by single decisive events (a champion duel, a hero's intervention, a betrayal). They do not narrate decades-of-attrition-erosion-via-economic-strangulation. The closest is the *generational* dimension of Iran-Turan conflict (Manuchehr → Kay Khosrow is many generations of war), but each generation's war resolves through battle-events, not through gradual economic-erosion.
- **Quartermasters, supply officers, granary-administration as narrative beats.** The epic names *military* officials (Tus the army commander, Giv as Kay Khosrow's loyal warrior, Bahram and Zangeh as generals); it does NOT name *administrative/logistical* officials in the way medieval European chronicles often do.

### Where the supply-line dimension exists (weaker form)

**(a) Famine / drought as wartime hardship.** The epic occasionally references hardship during prolonged campaigns — soldiers suffering, horses dying, armies needing to forage. But this is typically narrative *texture* (showing the moral cost of war) rather than narrative *cause* (this army lost BECAUSE of supply failure).

**(b) Garrison cities + siege-as-isolation.** The epic does narrate sieges where a fortified city is cut off and eventually falls (post-Kayanian era especially, as the epic moves toward Sasanian-era content). But Kayanian-era heroic-age content is light on siege; the Iran-Turan wars are mostly field-battles and frontier-raids.

**(c) Implicit supply dependence in the long-march descriptions.** When Iranian armies march into Turan (or vice versa), the epic describes the distance + terrain difficulty (Mazandaran's demon-haunted approaches; the Oxus crossing; mountain passes). The implicit understanding is that armies need to be sustained across these distances — but the epic doesn't dwell on the mechanics of how this sustainment happens.

### Historical-Iranist grounding (medium-high citation density)

**Historically — outside the epic — supply-line-decisiveness IS well-attested in pre-Islamic Iranian warfare.** The Achaemenid → Parthian → Sasanian periods all show extensive military-logistical infrastructure (depots, supply-chains, food-and-fodder logistics). Greek sources on the Persian invasions of Greece (Herodotus on Xerxes's 480 BCE expedition) attest sophisticated logistical planning. The Parthians' famous *Parthian shot* + their hit-and-retreat steppe-cavalry tactics depended on supply-base management. The Sasanian military had quartermaster-equivalent roles.

**But the Shahnameh is an EPIC, not an administrative-historical-record.** Ferdowsi compresses centuries of war-history into hero-narratives, and the logistical dimension that almost certainly mattered in actual ancient warfare is mostly absent from the epic-narrative he gives us.

### Verdict on the design thesis — the honest version

**The "armies require upkeep, supply-line vulnerability is decisive" mechanic is more historically-grounded than epically-grounded.** It maps onto the actual ancient-Iranian military reality (Achaemenid / Parthian / Sasanian) more strongly than onto Ferdowsi's narrative reality. **For a project whose primary source is the epic, this is a non-trivial concern.**

**Three options for handling this in the design chat:**

1. **Ship the supply-line mechanic anyway, grounding it on historical-administrative-Iran rather than on epic-narrative-Iran.** Defensible — the project has always treated the Shahnameh as a *frame* anchored to the broader ancient-Iranian-cultural-sphere, and the historical reality is part of that cultural sphere. But cultural-notes shipping this mechanic should be HONEST that the source is historical-administrative rather than epic-textual; don't fabricate Shahnameh-quote-mining.

2. **Ship the supply-line mechanic as a LATE-CAMPAIGN escalation rather than a baseline-economy-rule.** This honors the epic's pattern: early heroic-age content is champion-combat-decisive (where supply doesn't matter much); late-Kayanian + Sasanian-era content shifts toward war-of-attrition + siege (where supply does matter). The game's economy could mirror this — Tier-1/2 economy doesn't surface supply-line raidability much; Tier-3+ and campaign-later-stages introduce it.

3. **Soften the supply-line mechanic to "wealth-flow disruption" rather than "army-starves-and-loses".** The flow-can-be-raided mechanic is fine — it's a economic-pressure dimension that maps onto frontier-raiding-as-tactical-reality (Q3). But the further claim that *unguarded armies degrade or lose* should be moderated; the epic doesn't strongly support that battle-decisiveness framing.

### Refinement candidates flagged

- **Recommend: ship a version of (3) above** — the wealth-flow IS attackable (that's the canonical caravan-raid mechanic per Q3); but army-effectiveness-decay-from-upkeep-failure is a softer, slower effect, not a battle-deciding instant-loss mechanic. This honors both the epic's champion-decisive battle-narrative AND the historical-administrative reality of supply-line dependence.
- The design chat should explicitly decide whether the project's "primary source is Shahnameh" rule means (i) strict epic-textual citation only, or (ii) Shahnameh + broader ancient-Iranian-cultural-sphere as the source. This is a decision point the project hasn't formally made; the loremaster's read is (ii) (per CLAUDE.md + 00_SHAHNAMEH_RESEARCH.md treating ancient-Iranian context as part of the source-material space), but it deserves an explicit ratification.

---

## 5. Q5 — Escort / transport with armed guards as Shahnameh narrative element

### The framing claim

The thesis ships escort-automation (player assigns standing guards to a route; guarded vs unguarded routes have different raid-vulnerability). Lead asked: does this appear in the Shahnameh, or is it medieval-European-fantasy projection?

### Shahnameh-textual evidence

**Armed-escort-of-valuable-transport is canonical, though more in the form of "royal embassy/treasure protection" than as a standing-route-guard system.** Specific episodes and patterns:

**(a) Royal embassies traveling between kingdoms.** Across the epic, kings exchange messages, gifts, and ambassadors — often across the Iran-Turan frontier or to/from Rum / Hind. These embassies travel with armed retinues. The retinue is depicted as *part of the prestige and seriousness* of the embassy — a poorly-protected envoy is a sign of weakness or insult. The Siavoush story features his entourage when he flees to Turan; his Turanian wife Farangis is also protected by retainers loyal to her even after Siavoush's murder.

**(b) Tribute caravans + bridal trains.** When tribute moves between kings (Manuchehr collecting from Salm-Tur territories; Afrasiyab's tribute extraction from his subject peoples), the transport is escorted. Bridal trains (when a princess is given in marriage between kingdoms — e.g., Rudaba marrying Zal; Manizheh's complicated cross-border situation) are escorted with guards. **High-value transport with armed escort is the assumed default in the epic; an unescorted high-value transport would be exceptional.**

**(c) Rostam-as-caravan-master disguise.** Already cited in Q3 — Rostam adopts a caravan-master persona to infiltrate Turan in the Bizhan rescue. The disguise WORKS because caravan-masters traveling with armed retinues are *normal-looking* enough that Rostam-as-leader-of-an-armed-band-of-merchants doesn't immediately read as a foreign hero on a rescue mission. **This is implicit confirmation that armed-caravan-master with retinue is a recognizable, common figure in the epic's world.**

**(d) Hero campaigns with retinues.** Rostam, Esfandiyar, Giv, and the other named pahlavans travel with retinues — squires, pages, sworn retainers — not as lone-wolf knights. The hero is *protected* by his band as well as protecting them. **The "named warrior assigned to escort/protection-of-someone" pattern is throughout the epic.**

### Where the design's "standing-route-guard" mechanic is partially projection

**The "guards assigned to a fixed route" framing is more medieval-European-feudal-administrative than Shahnameh-specific.** Medieval Europe had specific institutional forms (the king's road wardens; specific patrolling-and-protection arrangements) that the epic doesn't directly mirror. The Shahnameh's escort pattern is **escort-OF-a-specific-transport** (this caravan, this embassy, this bridal train) rather than **escort-OF-a-route** (the route between A and B is protected as infrastructure).

**That said: the design's escort mechanic is FUNCTIONALLY equivalent to the epic's pattern**, just with the framing tilted. A "5 Piyade assigned to the south route" mechanic effectively means "any caravan moving along the south route is escorted." This is mechanically the same as the epic's "high-value transports are escorted by default." The design's framing is just slightly more *administratively-formalized* than the epic's narratively-implied baseline.

### Verdict on the design thesis

**Escort-of-armed-transport is well-grounded in the epic. The "standing route guards" mechanic is a defensible RTS-formalization of the canonical "high-value transports are escorted" pattern.** No serious cultural concern. Some prose-framing options for the design's implementation:

- **Cultural-honest framing:** the escort assignment is the player committing some of their *named warriors / sworn retainers* to caravan protection rather than to front-line warfare. This honors the epic's "every warrior is in someone's retinue" framing.
- **Avoid:** framing the escort as "patrolling generic guards on a road" — this is the medieval-European projection. The Shahnameh's military culture is *person-bound* (warriors swear oaths to lords, not to abstract roads). Frame the escort as "these warriors guard this caravan / this route" not "these guards patrol this stretch of infrastructure."

### Refinement candidates flagged

- **Cultural-note prose for the eventual escort mechanic** should explicitly cite Rostam-as-caravan-master-disguise (`Shahnameh` Bizhan-Manizheh arc) as the canonical caravan-with-retinue precedent. This anchors the mechanic narratively.
- If the project eventually surfaces a *named hero in escort role* mechanic (a pahlavan dedicated to protecting a route or transport), that's culturally rich — Giv or Bijan in this role would be canonical-feeling.

---

## 6. Q6 — Cultural anti-patterns to avoid (the hardest section)

### Why this section matters most

The dispatch specifically asked about three sub-questions:
1. Is "Turan raiding Iran" the only valid framing? (No — bidirectional. Already addressed in Q1 + Q3 above.)
2. Is wealth flowing UP to the takht the only legitimate flow, or did the Shahnameh era show counter-flows? (Important; addressed below.)
3. Is the "dehqan-Throne reciprocity" framing canonical Shahnameh, or Islamic-period concept being read backward? (**This is the section where I find a serious flag against my own prior project work.**)

I'm taking each in turn, with the third — the framing audit — getting the most space because the stakes for the project's existing cultural-notes are highest.

### 6.1 — Iran also raids Turan (NOT just Turan raiding Iran)

**Already established in Q1 + Q3 above.** The Iran-Turan wars are bidirectional. Iran-as-only-defender is wrong; Iran is *structurally* defensive (per the asymmetry) but Iranian armies invade Turan multiple times across the epic (Manuchehr; Kay Khosrow's campaign; Rostam's incursions; Esfandiyar). **Design implication: when the raid mechanic ships, both factions should be capable of raiding the other; Iran-side raid is just typically narratively framed as *retribution* or *war-of-revenge* (Iraj's blood; Siavoush's blood) while Turan-side raid is framed as *opportunism* or *aggression*. The mechanic is mirror; the cultural-prose-framing differs by side.**

### 6.2 — Counter-flows from the treasury (NOT just up-flow to it)

**The "wealth flows UP to the takht" framing is HALF of the Shahnameh's economic-political picture; the other half is wealth flowing DOWN as royal largesse / dispensation / patronage.** The epic is full of moments where:

**(a) Kings grant treasure to heroes and loyal followers.** Kay Khosrow rewards Rostam, Giv, Bizhan, and other pahlavans repeatedly with treasure, honors, lands, titles. Kay Kavus's court routinely distributes wealth. Even Afrasiyab on the Turanian side rewards loyal warriors with treasure — Piran-Viseh's stature depends partly on the gifts/rewards Afrasiyab has bestowed.

**(b) The king's duty INCLUDES dispensation.** A just king is one who *gives* as well as *receives* — hoarding the treasury without dispensing is a sign of unjust rule. The Shahnameh's moral framework is built around the just/unjust king axis, and one of the marks of just rule is **generous distribution from the royal treasury** to soldiers, to suffering subjects, to allies. Jamshid's golden age is depicted as a time when wealth flowed freely (before his pride corrupted the order); Zahhak's tyranny is marked partly by miserly hoarding.

**(c) Public works and royal infrastructure funding.** Kings build cities, palaces, fire-temples, irrigation works — all funded from the royal treasury flowing OUT into productive infrastructure. The Achaemenid Royal Road, Persepolis itself, the great fire-temples — these are wealth-flowing-down from the royal seat, not wealth-flowing-up to it.

### Implication for the design thesis

**The thesis's "wealth flows to the takht" is correct as the PRIMARY flow but should NOT be presented as the ONLY flow.** A culturally-honest economy model would include:
- **Up-flow:** tribute, taxes, harvest deliveries, raid spoils → throne treasury (this is what the current design ships).
- **Down-flow:** royal largesse, soldier pay, hero rewards, settlement infrastructure → from treasury to subjects (this is what's currently MISSING).

**The unit upkeep mechanic the design proposes is, in a sense, ALREADY this down-flow** — armies "cost" the throne, which means treasury wealth is being spent on military maintenance. So the mechanic does exist in nascent form. **What's missing is the cultural FRAMING that this down-flow is RIGHTEOUS RULE rather than DEFICIT/COST.** Refining the prose framing of upkeep from "armies require maintenance (cost)" to "the just king sustains his sepah from the treasury (royal duty)" honors the Shahnameh's moral picture.

**This is a small framing-only refinement, not a mechanic-changing one. But it shifts the cultural register meaningfully.**

### 6.3 — The "dehqan-Throne reciprocity" framing audit — SERIOUS FLAG

**This is the question where I have to be most honest, because the answer affects my own prior project work.**

**My finding: the *dehqan* concept in the sense the project's cultural-notes have been using it is partially Islamic-period-and-later, NOT Kayanian-heroic-age-canonical-Shahnameh.**

### What I had been claiming (in shipped cultural-notes)

Across multiple recent cultural-notes (Mazra'eh header; Throne header `throne.gd`; Wave 3-LocalDropoffs addenda just queued for Commit 1.5), I've been using "dehqan-Throne reciprocity" as a load-bearing framing — wealth flows from the dehqan's farmstead UP to the king's seat. The Throne wave's cultural-note explicitly frames the deposit-mechanic as "dehqan-Throne reciprocity — wealth flows to the takht."

### What the historical-Iranist record actually shows

**The *dehqan* (دهقان) as a specific social-administrative class is most strongly attested in the SASANIAN and EARLY-ISLAMIC periods**, NOT in the Kayanian heroic age the project is set in. Specifically:

- The dehqan emerges as a recognizable institutional category in late-Sasanian-era administrative-historical record (5th-7th centuries CE), as the *village-level landed administrator* responsible for tax collection, local justice, and cultural transmission.
- The dehqan's cultural-stewardship role — *custodian of pre-Islamic Iranian memory* — becomes especially load-bearing in the EARLY-ISLAMIC period, when the dehqan class is the bridge by which Sasanian-era + earlier-Iranian heritage is preserved into the Islamic centuries. **Ferdowsi himself was dehqan stock, writing in this preservation-role tradition.**
- Pre-Sasanian-era Iran (Achaemenid, Parthian, and earlier — the rough chronological space where the Kayanian heroic age is "set") had ITS OWN landed-cultivator social classes, but they were NOT called *dehqan* in the technical sense. The Achaemenid period's analogues were administrative-cultivator classes within the satrapy system; the Parthian period had different arrangements.

### What the Shahnameh actually says about the dehqan

**Ferdowsi uses *dehqan* primarily in TWO senses across the epic:**

1. **As a CONTEMPORARY (Ferdowsi's own time) social class** that he himself comes from, especially in the epic's frame-narrative + invocations + the prologue. "I am dehqan stock; I write to preserve the memory of the ancient kings." This usage is about Ferdowsi's own status and the act of preservation, NOT about the Kayanian-heroic-age social structure he's narrating.

2. **As a NARRATIVE-ETHNOGRAPHIC marker for "person of the landed cultivator class"** when describing characters in the epic's chronological frame — used somewhat anachronistically, as Ferdowsi paints the Kayanian-heroic-age social world with brushstrokes from his own contemporary Sasanian/early-Islamic understanding.

**The "dehqan-Throne reciprocity" as a Kayanian-heroic-age canonical institutional relationship is therefore PARTIALLY ANACHRONISTIC.** What's accurate:
- There was *some* form of cultivator-to-king tribute relationship in the Kayanian-heroic-age the epic narrates (the structural reality is real even if the technical term *dehqan* doesn't apply to that period).
- Ferdowsi's own contemporary dehqan-cultural-memory-preservation role is real and important and well-attested.
- The Sasanian-and-later dehqan-Throne tax-tribute system is real and historically attested.

**What's stretched:**
- Using "dehqan-Throne reciprocity" as a label for Kayanian-heroic-age economic-political structure as if it were a canonical institutional category from that period. **Strictly speaking, this is Sasanian-and-later terminology being read backward into the heroic-age setting.**

### How serious is this finding?

**Honest assessment: moderate, not severe. The framing is recoverable.**

The Shahnameh itself is a *poetic compression of multiple historical periods* — Ferdowsi narrates Kayanian-heroic-age content with poetic + social texture drawn from his own Sasanian/early-Islamic understanding. The epic ITSELF is doing the "read later concepts backward into earlier periods" move; it's the epic's STANDARD MOVE. **The project's use of "dehqan" in its cultural-notes is following Ferdowsi's own practice**, which is defensible.

But: there's a difference between (a) honoring Ferdowsi's compression-and-projection move (which the project is doing) and (b) presenting the projection as if it were *canonical Kayanian-heroic-age fact* without acknowledging the chronological compression. **The project's current cultural-notes don't acknowledge this; they present "dehqan-Throne reciprocity" as if it were a load-bearing structural fact of the heroic age.**

### Refinement options for the project's existing cultural-notes

**Three options, ordered by cost:**

**Option A (lowest cost — recommended): Add a sentence acknowledging the chronological compression in the shared/general cultural framing.** Add to (e.g.) `00_SHAHNAMEH_RESEARCH.md` or to `docs/ANCHOR_CATEGORY_TAXONOMY.md` a note acknowledging: *"The project uses the term 'dehqan' in the sense Ferdowsi uses it — a compression of Sasanian-era + early-Islamic social-administrative reality projected backward into the heroic-age setting. The Kayanian-heroic-age period the epic narrates predates the technical dehqan class by centuries; Ferdowsi honors his own dehqan-cultural-memory tradition by reading it into the deep past. The project follows the epic's framing."* **One paragraph, one location, points downstream to all dehqan-citing cultural-notes.**

**Option B (medium cost): Edit existing cultural-notes to mark "dehqan" usage as "in Ferdowsi's sense."** Less elegant; touches multiple files; risks creating subtle inconsistencies.

**Option C (high cost — not recommended): Remove "dehqan" from cultural-notes and substitute period-accurate terms.** Loses the cultural-resonance of the term Ferdowsi himself uses and that the project has been building around. Would require substantial rework.

**Recommendation: Option A.** A single-paragraph clarification at the project's research-doc layer (00_SHAHNAMEH_RESEARCH.md is the natural home, with `docs/ANCHOR_CATEGORY_TAXONOMY.md` as a cross-reference), pointing downstream. Existing cultural-notes don't need editing because they're already following Ferdowsi's own practice; they just need the discipline-doc layer to acknowledge the practice's chronological-compression nature.

### Other "Islamic-period-read-backward" concerns to flag

While I was checking the dehqan, other candidates for "concept I've been using as canonical-Kayanian that may actually be later":

- **"Royal treasury" (*ganj*) as institutional fact.** Likely OK — the concept of royal treasury IS attested in the pre-Sasanian period; my prior usage is defensible.
- **The Atashkadeh as fire-temple institution.** The specific institutional form of *Atashkadeh* as a structured Zoroastrian fire-temple is best-attested Sasanian; pre-Sasanian fire-veneration was different in form. The project's existing `atashkadeh.gd` cultural-note already acknowledges the Sadeh-festival anchor at Hushang's discovery — that's heroic-age-canonical. The institutional-temple-form is a slight projection but defensible per the same "Ferdowsi's compression" pattern.
- **The Farr-ī Yazdān concept.** Solidly heroic-age-canonical. Avestan + early-Iranian theological-political concept, not a back-projection. Safe.
- **The pahlavan-class champion combat (*mard-o-mard*).** Heroic-age-canonical. Safe.

### Verdict on the design thesis

**The thesis's economic-political framing IS culturally honest as a Ferdowsi-style compression of pre-Islamic Iranian reality. But the project should explicitly ACKNOWLEDGE that this is a compression rather than presenting it as if it were strictly Kayanian-heroic-age structural fact.** This is a discipline-doc-level acknowledgment, not a cultural-notes overhaul.

The "wealth-flow-IS-the-contest" design thesis is, in itself, more aligned with the actual structural reality of pre-Islamic Iran (where the imperial centers DID rest on tribute-and-tax administrative flows) than the SC2-army-economy model is. It's the more culturally-honest design space — even with the chronological-compression caveat.

---

## 7. Synthesis — net verdict + the two material refinements

### Net verdict

**The Trade & Transport economy thesis fits the Shahnameh well, with two material refinements that should land before Phase-4+ implementation locks.** Both refinements are absorbable; neither breaks the thesis.

### Material refinement #1 — Acknowledge the "dehqan-Throne reciprocity" chronological compression

**Per Q6.3 above.** Add a one-paragraph clarification to `00_SHAHNAMEH_RESEARCH.md` (with cross-reference from `docs/ANCHOR_CATEGORY_TAXONOMY.md`) acknowledging that the project follows Ferdowsi's own practice of reading the dehqan-cultural-administrative framing backward into the heroic-age setting. This is a discipline-doc-level honesty move; existing cultural-notes don't need editing.

**Routing:** design-chat ratification → loremaster edits 00_SHAHNAMEH_RESEARCH.md (small surface; ~one paragraph). This is the lowest-cost-highest-value finding from this research.

### Material refinement #2 — Moderate the "supply-line decisive in battle" framing

**Per Q4 above.** The epic's battle-narrative is champion-combat-decisive, not supply-line-decisive. The project should:
- Ship the *wealth-flow attackable* mechanic as designed (Q3 confirms this is canonical at the frontier-raiding level).
- Moderate the *army-effectiveness degrades from upkeep-failure* mechanic to a slower, soft effect rather than a battle-decisive instant-loss mechanic.
- Reframe upkeep as "the just king sustains his sepah from the treasury (royal duty + down-flow as righteous rule)" rather than as "armies require maintenance (cost + deficit)" — this honors both the Q4 historical-vs-epic split AND the Q6.2 counter-flow finding.

**Routing:** design-chat to decide whether to incorporate; this affects the gameplay-feel of Phase-4+ upkeep mechanics.

### Other findings that are framing-shifts, not refinements

- **Bidirectional raiding** (Q1 + Q3): both factions should be capable of raiding. Iran-as-only-defender is wrong.
- **Turan has named courts and royal seats** (Q1): cross-faction-near-symmetry applies to Throne and possibly other building categories case-by-case.
- **Bizhan-Manizheh is the strongest narrative anchor for caravan-mechanics** (Q3): cite at design-chat time if/when the caravan mechanic gets a kickoff brief.
- **Royal largesse / down-flow is canonical and currently missing from project framing** (Q6.2): cultural-note prose can be enriched to honor this when relevant; not a structural mechanic-change need.

### Forward-watch — what this research means for Phase-4+ design chat

When Trade & Transport ships as a Phase-4+ kickoff brief, the loremaster brief-time review should:
- Verify the cultural-prose-framing of upkeep honors the down-flow + righteous-rule shape (Refinement #2).
- Verify bidirectional raid capability is on the table (or the deferral is explicit).
- Cite Bizhan-Manizheh as the canonical caravan-mechanic narrative anchor.
- Apply the J2 trichotomy at the new-building level if new buildings ship (Caravanserai? Granary? Mint?) — likely some will be taxonomy-growth-required candidates.

### What this research does NOT decide

- **Whether to ship Trade & Transport at all.** The thesis is culturally well-grounded; design-chat decides whether the MVP-vs-post-MVP scoping and the design-bandwidth tradeoff are worth it.
- **Specific Phase-4+ implementation details.** Mechanics like "how many caravan types? Player-built or automatic-spawn? How are guards assigned?" are design-chat territory, not loremaster territory.
- **The exact form of any cultural-notes-edits for the dehqan-compression acknowledgment.** Surfaces here as a finding; the actual edit prose comes at design-chat-ratification-time.

---

## 8. Honest J4 split — where my source-material competence is high vs. lower

Applying the loremaster lens to my own work in this doc:

**High confidence (Shahnameh-textual citations I can defend in detail):**
- Q1 evidence (Fereydun tripartite division; Iran-Turan asymmetry as textually-grounded; bidirectional raiding canon).
- Q3 evidence (Bizhan-Manizheh caravan-as-cover; Afrasiyab's tactical signature; frontier-raiding patterns).
- Q5 evidence (escort-of-transport as canonical; Rostam-as-caravan-master disguise).
- Q6.1 + Q6.2 (bidirectional raiding; royal largesse + down-flow framing).

**Medium confidence (citing general historical-Iranist consensus rather than specific scholarly sources):**
- Q2 historical-Iranist content (Achaemenid Royal Road; Sasanian kharaj; satrapy tribute system). Recommended scholarly anchors: Touraj Daryaee + Richard N. Frye; I have not directly read these in this dispatch's preparation, am citing from general Iranist-reading consensus.
- Q4 historical-administrative-Iran content (military logistics; supply-chain reality across imperial periods).
- The Achaemenid-vs-Parthian-vs-Sasanian dating distinctions throughout.

**Lower confidence (loremaster interpretation that should be explicitly marked as opinion):**
- Q6.3's serious-flag claim that "dehqan" as institutional concept is partially Sasanian-and-later. **This is my read; I am not an Iranist specialist on this question.** The finding deserves design-chat sanity-check before any 00_SHAHNAMEH_RESEARCH.md edit. If a Shahnameh-khani scholar or Iranist consults on this point and disagrees, my finding should be revised. **Flagged explicitly as the area most likely to need expert verification.**

**Confidence-level disclosure is the J4 discipline working as designed.** I am surfacing the dehqan-compression flag because the J4 lens demands honest intent-vs-claim distinction; I am ALSO flagging that this specific finding is the one I have lowest expert-confidence on, so design-chat can weight it accordingly.

---

## 9. Version history + next-version triggers

- **v1.0.0** (2026-05-25) — Initial cross-check. Six research questions answered. Two material refinements proposed (dehqan-compression acknowledgment; supply-line-decisiveness moderation). Multiple framing-shifts surfaced (bidirectional raiding; counter-flows from treasury; Turan-has-named-courts cross-faction-applicability). Honest J4 confidence-disclosure in §8.

**Next-version triggers:**
- Design-chat ratification of any of the refinements → PATCH bump documenting the ratification + any resulting 00_SHAHNAMEH_RESEARCH.md edits.
- Iranist-expert consultation on the dehqan-compression flag (Q6.3) → PATCH or MINOR bump depending on outcome. If the flag is confirmed, the recommendation stands; if disputed, the doc revises.
- Phase-4+ Trade & Transport kickoff brief → cross-reference from the brief back to this doc; the doc itself may get refinements based on what the design-chat actually decides to ship.

---

*Skynda långsamt. The economic-political structure of pre-Islamic Iran is real, attested, and richer than any single design pass can capture. This research is one cross-check at one moment; future research will refine, contradict, or extend.*
