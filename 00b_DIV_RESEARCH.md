# Divs — Lore Research and Economic Mechanic Proposals

*Research deliverable for the future Divs faction. Not blocking the current MVP.*
*Authored: 2026-04-30. Author: Claude Code (research agent).*
*Companion to `00_SHAHNAMEH_RESEARCH.md` §2 (Kayanian) and §4 (Divs unit table).*

---

## Executive Summary

The user's instinct is correct: **a Divs faction that gathers grain from farms is wrong for the source material.** In Zoroastrian theology — which is the cosmological scaffolding underneath the Shahnameh — evil is **parasitic by design**. Ahriman has no creative power; he can only counter-create against Ahura Mazda's creation, then sustain himself by corrupting, devouring, or stealing what already exists. The Divs are field agents of that parasitism.

This document does two things:

1. **Section 1 — Lore** consolidates what reputable scholarship (*Encyclopaedia Iranica*, Wikipedia citing Ferdowsi, the Smithsonian Shahnama project, the Fitzwilliam Shahnameh project) actually says about the Divs: their etymology, their key named individuals, their territory, their sustenance, and their weaknesses.

2. **Section 2 — Game design** proposes **four distinct economic mechanics**, each grounded in a specific lore element, each replacing or warping the Iran/Turan worker-and-farm loop into something *Shahnameh-faithful*. The four are:

   - **A. The Tributary Gulag** (Tahmuras inverted — bound mortals forced to gather)
   - **B. The Devouring Hunger** (Az's parasitism — kill enemies to feed your economy)
   - **C. The Shadow-Spread** (corrupted terrain as passive resource)
   - **D. The Brain-Tax** (Zahhak's serpents — your own units are the resource)

   Each is rated for lore-fit and Godot/GDScript implementation difficulty. The recommendation at the end is a hybrid: **A as the spine, with C providing a passive layer.**

The bar for any final design is the same as the rest of the game: **every mechanic must read as something Ferdowsi would recognize, and must be implementable in GDScript at MVP-equivalent complexity** (i.e., post-MVP, not first-shipped MVP).

---

# Section 1 — The Lore

## 1.1 Etymology and Zoroastrian context

The Persian word **div / dīv / dēw** (دیو) is the direct linguistic descendant of Avestan **daēva** (𐬛𐬀𐬉𐬎𐬎𐬀), and behind that the Proto-Indo-European *deywós* — the same root that gives Sanskrit *deva*, Latin *deus*, and English *divine*. In the older Indo-Iranian religious layer, the *daēvas* were simply gods. **Zoroaster's reform inverted them.**

In the *Gathas* — the oldest Avestan texts, attributed to Zoroaster himself — the *daēvas* are described as "rejected gods": real beings, but morally illegitimate, worshipped by those outside Mazda-worship. Over the next millennium of Zoroastrian theological development, the inversion completed. By the time of the *Vendidad* and the Pahlavi (Middle Persian) commentaries, *daēva → dēw → dīv* had become unambiguously demonic: servants of Angra Mainyu / Ahriman, the destructive spirit, opposed to the truthful order of Ahura Mazda.

This is the cosmological inheritance Ferdowsi works with a thousand years later. By the time the *Shahnameh* is being composed (c. 977–1010 CE), the Divs are no longer "rival gods" — they are the canonical antagonist class of the Persian mythic imagination. Three structural facts about them, established by Zoroastrian cosmology, persist into the epic:

1. **Evil is parasitic, not creative.** Ahriman has no independent creative power. He can only attack, counter-create, corrupt, or invade what Ahura Mazda has already made. Divs as his agents inherit this property.
2. **Divs are made of darkness, opposed to fire.** Ohrmazd shaped his creations as "bright, white fire"; Ahriman made his demonic creatures out of darkness. Fire — sacred fire on the *atashkadeh*'s altar — is literally and theologically the counter-element.
3. **Divs are concrete; they walk the earth.** Unlike abstract Christian demons, divs are physical, named, embodied beings. They get punched. They bleed. Rostam puts the White Div's heart and blood to topical use.

**Sources:** [Encyclopaedia Iranica — DĪV](https://www.iranicaonline.org/articles/div/), [Encyclopaedia Iranica — DĒW](https://www.iranicaonline.org/articles/dew/), [Daeva — Wikipedia](https://en.wikipedia.org/wiki/Daeva), [Zoroastrian cosmology — Wikipedia](https://en.wikipedia.org/wiki/Zoroastrian_cosmology), [Encyclopaedia Iranica — COSMOGONY i.](https://www.iranicaonline.org/articles/cosmogony-i/).

## 1.2 Named Divs in the Shahnameh

| Div | Role | Defeated by | Defining trait |
|---|---|---|---|
| **Div-e Sepid** (دیو سپید, "White Div") | Chieftain of the Divs of Mazandaran. Captures Kay Kavus's army with a conjured storm of hail, boulders, and tree-trunks, then blinds them and imprisons them in a dungeon. | Rostam, Seventh Labor. His heart and blood, applied as a salve, restore the Iranians' eyesight. | Massive size, sorcery, mastery of illusion-storms. The proper "boss" Div of the epic. |
| **Arzhang Div** (ارژنگ دیو) | Lieutenant of Div-e Sepid; commander of the demon army; appointed guardian over the captured Iranian treasure on Mount Espand. | Rostam, en route to Div-e Sepid. Rostam summons him with a thunderous shout from outside his tent; severs his head; throws it among the assembled divs. | Military commander. The Div who gives "command structure" to demons. |
| **Akvan Div** (اکوان دیو) | A whirlwind / shape-shifting Div appearing as a wild ass with a yellow hide and a black stripe from mane to tail. Snatches sleeping Rostam, lifts him into the sky, asks whether to drop him on a mountain or in the sea. Rostam reverses the question; Akvan throws him in the sea (Rostam survives). | Rostam, with lasso, after Rostam returns and confronts him a second time. | Trickery, illusion, perversity, contrarianism. Cannot be defeated by force alone — Rostam has to outwit him. |
| **Aulad Div** (اولاد) | A "lesser" Div / provincial demon-king encountered earlier in the Seven Labors. | Captured alive by Rostam, bound, forced to serve as guide to Div-e Sepid's lair. Critically, **Aulad reveals to Rostam the Divs' weakness: they are weakest at noon, in full daylight.** | Bound and used. The Div who is enslaved, not killed. The Tahmuras pattern in miniature. |
| **The lesser, unnamed divs** | The mass-army Divs of Mazandaran. Conjurers of fog, hail, blinding storms. Ambushers. | Mostly cut down by Rostam and Iranian heroes during the assault on Mazandaran. | Sorcerous mob. Disposable mooks with magical battlefield effects. |

### The two "founding" Divs (older than the Heroic Age)

| Figure | Pishdadian-era role | Why it matters for design |
|---|---|---|
| **Ahriman** (اهریمن) | The ur-evil. Not a Div but the *source* of Divs. Tempts Zahhak; kisses his shoulders; the kiss germinates the two black serpents. | Establishes that Divs are **agents of corruption from above**, not autonomous beings. Their power flows from a superior. |
| **Zahhak** (ضحاک) | The serpent-shouldered tyrant. Not a Div himself, but Div-corrupted. The serpents on his shoulders demand the brains of two young men *every day*, fed as a daily stew. | Establishes the **brain-tax economy**: Div-aligned tyranny survives by daily, ritualized human sacrifice from its own population. |
| **Tahmuras Divband** (طهمورث دیوبند) | The demon-binder. The Pishdadian king who *defeated* two-thirds of the Divs in battle and *bound* them with magic; the third he crushed with his mace. The bound Divs, as ransom for their lives, taught humanity **thirty scripts**. | Establishes the inversion: **Divs as bound, captive knowledge-givers and laborers under coercion.** This is the single most fertile lore-thread for an asymmetric Divs economy. |

**Sources:** [Div-e Sepid — Wikipedia](https://en.wikipedia.org/wiki/Div-e_Sepid), [Akvan Div — Wikipedia](https://en.wikipedia.org/wiki/Akvan_Div), [Encyclopaedia Iranica — AKVĀN-E DĪV](https://www.iranicaonline.org/articles/akvan-e-div-the-demon-akvan-who-was-killed-by-rostam/), [Arzhang Div — Wikipedia](https://en.wikipedia.org/wiki/Arzhang_Div), [Rostam's Seven Labours — Wikipedia](https://en.wikipedia.org/wiki/Rostam%27s_Seven_Labours), [Tahmuras — Wikipedia](https://en.wikipedia.org/wiki/Tahmuras), [Zahhak — Wikipedia](https://en.wikipedia.org/wiki/Zahhak), [The Death of Zahhak — Aga Khan Museum](https://collections.agakhanmuseum.org/collection/artifact/the-death-of-zahhak-akm155), [Mazandaran (Shahnameh) — Wikipedia](https://en.wikipedia.org/wiki/Mazandaran_(Shahnameh)).

## 1.3 Where the Divs live: Mazandaran

In the Shahnameh, **Mazandaran is the demon-haunted zone**. The text is explicit: it is so fearful a land that *no Shah of Iran dared try to conquer it* — neither Jamshid in his glory nor mighty Fereydun. The name appears 63 times in the epic, more than enough to mark it as a major geographic concept rather than a passing place.

It is **not** modern Mazandaran province (the Caspian-shore region of Iran). Scholars place "Shahnameh Mazandaran" variously in India, the Levant, or Egypt — there is no consensus, and the most useful read is *Mazandaran-as-mythic-space*: a land where the rules of mortal kingship break down, sorcery prevails, and hostile supernature is the dominant fact of geography.

When Kay Kavus invades Mazandaran, against all advice, his army is destroyed by a Div-conjured storm of hail and boulders, and the king himself is blinded and imprisoned. Rostam's Seven Labors — Iran's defining heroic sequence — exist *because* Kay Kavus's invasion failed. Mazandaran is the place that produces the heroic test.

For RTS design purposes, this is the home territory of the Divs faction.

**Source:** [Mazandaran (Shahnameh) — Wikipedia](https://en.wikipedia.org/wiki/Mazandaran_(Shahnameh)).

## 1.4 How do the Divs sustain themselves?

This is the key question for the user's instinct. The lore answer is structurally clear and worth quoting at design length.

### They do not farm. They do not gather. They are not productive.

There is no canonical scene in the Shahnameh, the Avesta, or the Pahlavi commentaries of Divs *cultivating fields*, *mining ore*, or *raising livestock for food*. Productive labor is associated with Ahura Mazda's good creation: Hushang's discovery of fire, Jamshid's invention of crafts, Tahmuras's building of cities. The Divs are on the other side of that ledger.

### Their power is parasitic by design

Per *Encyclopaedia Iranica* and standard Zoroastrian cosmology: **"Evil is parasitic: it has no independent creative power of its own but exists by attacking what Ahura Mazda has made."** This is not a poetic flourish — it is a structural theological claim that runs through every layer of the tradition. Ahriman did not create the world; he *invaded* a world Ahura Mazda had already made.

The Divs operate this way concretely:

- **Raids and ambushes.** Divs ambush armies (the Kay Kavus invasion); they "sow famine and plague" and conduct nocturnal raids on villages.
- **Theft.** Arzhang Div is appointed *guardian over the captured Iranian treasure* — Divs hoard what they have stolen from the just kingdom rather than producing wealth themselves.
- **Coercion of the corrupted.** Once Zahhak is corrupted, his agents seize men daily and execute them so the brains can feed the serpents. The economy of Zahhak's tyranny is a daily extraction tax of human lives from his own population — coerced sacrifice, not production.
- **Soul-feeding and devouring.** The demon **Az** (آز) — "Greed / Concupiscence / Avarice" — is named in the Shahnameh's list of ten demons. In Zoroastrian eschatology, Az is the *last* demon to be defeated, alongside Ahriman himself. Az is described as "Hylē, Matter, Evil itself" — the demonic principle of devouring. Az "destroys man's physical strength" by gluttonous consumption; Az is "let loose already on Gayōmard, the Primordial Man." This is the Zoroastrian template for *demonic economy*: appetite without productive output.

### Their power is sustained by darkness, sorcery, and the absence of fire

- Divs **thrive in shadow**; daylight saps their vigor (Aulad explicitly tells Rostam that Divs are weakest at noon).
- Divs are **made of darkness** (counter-creation cosmology, §1.1).
- Divs **fear and oppose fire** — the sacred element of Ahura Mazda. Fire-purification rites in the *Vendidad* are prescribed specifically as anti-Div measures. Encircling flames, recited *yashts*, and the Atashkadeh's perpetual flame are all Div-repellents.
- Divs use **sorcery and illusion** as their primary battlefield expression: Div-e Sepid's storm of hail and boulders, Akvan's whirlwind shape-shift, the conjured fogs that blind Iranian armies in Mazandaran.

### In one sentence

**Divs do not produce; they steal, devour, corrupt, and coerce. Their economy is the inverse of an honest harvest.**

**Sources:** [Encyclopaedia Iranica — ĀZ](https://www.iranicaonline.org/articles/az-iranian-demon/), [Daeva — Wikipedia](https://en.wikipedia.org/wiki/Daeva), [The Demon Div: The Terrifying Horned Demon of Chaos](https://thehorrorcollection.com/demon-div-terrifying-horned-demon-of-chaos/), [Divs and Devs — Fyelf](https://fyelf.com/mythical-creatures/divs-and-devs-ancient-foes-in-the-myths-of-persia-and-armenia/), [Zoroastrian cosmology — Wikipedia](https://en.wikipedia.org/wiki/Zoroastrian_cosmology).

## 1.5 How heroes defeat the Divs — the canonical weaknesses

For Iran-side counter-mechanics, this matters. Five repeating themes:

1. **Force of arms — but only by Pahlavans.** Regular soldiers cannot reliably kill Divs. It takes Rostam, Esfandiyar, Tahmuras. This justifies the asymmetry: **Divs eat normal armies; heroes are the answer.**
2. **Daylight.** Aulad tells Rostam to wait until noon before attacking Div-e Sepid. Divs are weakest in full sun. Mithra's light is anti-Div.
3. **Iron and binding.** Across folklore tradition, iron horseshoes nailed above thresholds repel Divs; iron needles or rings *bind defeated Divs as servants* after the fight. Tahmuras's whole gimmick is that he *bound* two-thirds of the Divs — they did not die, they became coerced labor.
4. **Fire and recitation.** Sacred flame and recited *yashts* (Zoroastrian liturgical hymns) repel Div sorcery. The *atashkadeh* is, in lore terms, a Div-warding installation.
5. **Outwitting.** Akvan cannot be killed by force alone; Rostam has to *reverse* the question (the perverse Div will do the opposite of what is asked). Cleverness defeats trickery.

For game design: a Divs faction whose units are *bound, coerced, daylight-vulnerable, fire-hostile, and trickster-prone* is canon. Iran's counter-mechanics — fire temples, hero-led raids at noon, lasso-and-bind unit captures — are also canon.

**Sources:** [Rostam's Seven Labours — Wikipedia](https://en.wikipedia.org/wiki/Rostam%27s_Seven_Labours), [Div-e Sepid — Wikipedia](https://en.wikipedia.org/wiki/Div-e_Sepid), [The Demon Div — The Horror Collection](https://thehorrorcollection.com/demon-div-terrifying-horned-demon-of-chaos/), [Tahmuras — Wikipedia](https://en.wikipedia.org/wiki/Tahmuras).

---

# Section 2 — Game-Design Translation

## 2.1 Design constraints — what we are designing against

Before proposals, the constraints:

- **Iran's economy** (`01_CORE_MECHANICS.md` §3): workers (Kargar) gather **Coin** from depletable mines and **Grain** from player-built farms on fertile tiles. Three resources total, the third being **Farr** (a non-spendable civilization meter).
- **Turan's MVP economy:** mirrors Iran. Future asymmetry will revolve around **Zur** (the Turanian counter-meter) and a more raid-oriented relationship to grain.
- **Divs are post-MVP.** They appear initially as a campaign antagonist, not a playable faction. Whatever economy they use ships *after* the Iran-vs-Turan loop is solid. This relaxes the "must be implementable in MVP" constraint — but tightens the "must feel right" constraint, because by the time Divs ship, expectations are higher.
- **The "Shahnameh-faithful" bar.** Every mechanic must point at a specific lore element a player or scholar can name. Generic "evil faction with corruption" mechanics fail this bar. Mechanics that quote Az, Tahmuras, Zahhak, or Mazandaran by name pass it.
- **Implementability.** Godot 4 + GDScript. No engine pyrotechnics. Reuse the `EventBus`, `FarrSystem`, `ResourceSystem`, and `SpatialIndex` already specified in `02_IMPLEMENTATION_PLAN.md`.

## 2.2 The four proposals

### Proposal A — The Tributary Gulag (Tahmuras inverted)

**Lore basis.** The Tahmuras Divband episode is the cleanest lore source for an *involuntary labor* Divs economy — but reversed in time. Where Tahmuras bound the Divs and forced them to teach scripts, the Divs faction in MMV (Mazandaran heroic age) **bind the *mortals* of conquered lands** and force them to gather. Aulad in chains is the visual ancestor. So is Zahhak's brain-tax (§1.2): Divs sustain themselves by extracting from a captive population.

**Mechanical proposition.**
- Divs do **not** train workers. They have no Kargar equivalent.
- Divs spawn cheap, fragile **Capturer** units (lesser divs, lasso-equipped — visually echo Aulad bound to a tree).
- Capturers cannot gather. Their job is to **lasso and drag enemy workers (or neutral villagers spawned at neutral "village" map features) back to a Divs building called the *Bandkhaneh* (بندخانه, "binding-house") or *Zindān* ("dungeon").**
- Each captured mortal becomes a **Bound Worker** unit, stationed at the Bandkhaneh. They gather Coin and Grain from the same map nodes Iran/Turan use, but at reduced efficiency (coerced labor).
- Bound Workers slowly lose HP over time (the bound state corrodes them). They must be replaced by fresh captures. **Population-from-prey, not population-from-houses.**
- **Houses are replaced by Bandkhaneh expansions** — each Bandkhaneh holds N captives.

**How it differs from Iran.** Iran: build economy → train workers → workers gather. Divs: build economy → train *raiders* → raiders steal *Iran's* workers → those workers, now bound, gather *for the Divs*. The Divs economy is literally a redistribution of someone else's economy.

**Tradeoffs and balance implications.**
- Strong early-game raid pressure (Divs *must* raid to economy-up), pushing Iran into early-defense gameplay that the Shahnameh gestures toward (the Iranian frontier under constant Turanian / supernatural threat).
- Weakness: if Iran walls up, Divs starve. Counter-balanced by neutral villages on the map (Mazandaran's mortal vassals) that Divs can capture without engaging Iran.
- Bound Worker decay creates a constant pressure loop — Divs *cannot rest*. Aligns with the "demonic restlessness" lore.
- Risk: the visuals of forcibly-dragged civilians is dark. This is *Shahnameh-canonical* (Zahhak's daily two-brain tax is far darker), but design must handle it carefully — abstract presentation, no torture animations. The reference is the Aulad-bound-to-a-tree miniature, not Game of Thrones.

**Implementation difficulty.** **Medium.** Requires:
- New unit type (Capturer) with a lasso ability that interrupt-converts a target enemy unit on contact (`UnitState.transition_to("Captured")`).
- New unit state for "Bound" (target unit's team flips, applies HP-decay tick via the existing simulation tick).
- New building (Bandkhaneh) that acts as a population container.
- Modifications to the AI economy controller to schedule capture raids.
- Most complexity is in the *capture mechanic itself* — graceful interrupt of an enemy unit's state machine, ownership flip on the EventBus, UI/feedback for the victim's player. The state machine contract from `STATE_MACHINE_CONTRACT.md` already supports interrupts; this is a clean extension, not a retrofit.

**Lore-fit grade: A.** Quotes Tahmuras-Divband, Aulad, and Zahhak's coercion economy directly. The "captive forced laborer" motif is one of the most visually recognizable in Shahnameh manuscript illustration.

---

### Proposal B — The Devouring Hunger (Az's parasitism)

**Lore basis.** **Az** (Avestan: Āz; Persian: آز) — the demon of greed, lust, and devouring concupiscence. Per the *Encyclopaedia Iranica* entry, Az represents "gluttony as opposed to contentment," is "the most serious menace to pious striving," and is in eschatological terms one of the *last two demons* to be defeated (alongside Ahriman). Az "destroys man's physical strength" through consumption. The Shahnameh names Az in its list of ten demons. The cosmological frame is parasitic-creation: evil has no productive power of its own.

**Mechanical proposition.**
- Divs have **no resource gathering at all.** No Coin nodes, no Grain farms.
- Every kill — by *any* Div unit, of *any* enemy unit (worker, soldier, hero, even animal) — generates resources directly. Call it **Az** (the resource), spelled in HUD as a single coin-equivalent currency. The Div faction is monocurrency.
- Different prey yield different Az amounts: enemy worker = small, enemy soldier = medium, enemy hero death = massive, enemy building destroyed = bonus payout.
- Buildings constructed by *consuming Az* and (critically) **a friendly Div unit, sacrificed at the build site.** "The hunger consumes itself to make a fortress."
- Population cap is not a cap on Divs — it is a cap on **how much they can eat**. Divs cannot field more than N units because *the Hunger demands its share and there is no more*. The cap rises only by killing enemy commanders.

**How it differs from Iran.** Iran economy is a *production curve*: build farms → grain accumulates → grain spends. Divs economy is a *predation curve*: find enemy → kill enemy → resource accumulates → resource spends. **A Divs player who is not actively in combat is starving.** This forces aggressive play and gives the faction a deeply different *rhythm*.

**Tradeoffs and balance implications.**
- Brutal early game if the Divs cannot find enemies. (Solution: neutral spawns — wandering "wild beasts" or "lesser divs" on the map serve as starter prey.)
- Strong snowball: kill more → more units → kill more. Counter: diminishing returns curve on Az per kill, so the 50th kill yields less than the 5th.
- Iran's existing Farr "snowball protection" (see §4.3 of `01_CORE_MECHANICS.md`) becomes thematically perfect: as Iran's army shrinks 3:1 against the Divs, Iran *loses* Farr but the Divs *lose* Az-gain efficiency. The two anti-snowball forces converge from opposite directions.
- Risk: gameplay-y feel. "Kill = money" is a familiar mechanic from many games (Diablo, ARPGs). Risk of feeling generic. Mitigation: name and present it as Az specifically; floating "+12 Az" with a brief Persian-script flourish; HUD frame styled with the demon's iconography.

**Implementation difficulty.** **Light to medium.**
- The single mechanic of "every kill generates resource" is a one-handler hook on `EventBus.unit_died`.
- Building-cost-includes-unit-sacrifice is one extra resource type ("Friendly Div Sacrificed") consumed on building placement.
- The hard part is the diminishing-returns curve and balance — but that's a `BalanceData.tres` value, not architecture.
- Removes the entire worker/farm/mine subsystem. Net code is *simpler* than Iran's economy, not more complex.

**Lore-fit grade: A.** Names Az directly and quotes the cosmology of parasitic creation. Az is among the most theologically-loaded demons in the Avestan tradition and underused in popular mythology games. Distinctive.

---

### Proposal C — The Shadow-Spread (corrupted Mazandaran)

**Lore basis.** Mazandaran as the demon-haunted zone (`00_SHAHNAMEH_RESEARCH.md` §5.5 and Wikipedia's Mazandaran-Shahnameh entry). Divs do not farm fields — *the land itself, when corrupted, oozes for them*. Cosmology: counter-creation, where Ahriman's invasion *taints* what Ahura Mazda made. Daylight saps Divs (Aulad's tip to Rostam); shadow nourishes them.

**Mechanical proposition.**
- Divs build a single "central well of darkness" called the **Chah-e Tarik** (چاه تاریک, "Dark Well") or **Damgah-e Ahriman** ("Ahriman's Snare") at game start.
- The Dark Well projects a slowly-expanding **Shadow Zone** outward — visualize as a creeping purple/black tint on the terrain, replacing normal map texture.
- Inside the Shadow Zone, the Divs faction passively gains resources at a rate proportional to the *area* of corrupted terrain. No worker labor — the corrupted land *bleeds* for the Divs.
- The Shadow Zone expansion can be accelerated by building **secondary wells** (Atashkadeh-equivalents, but inverted) at additional sites.
- **Counter-mechanics for Iran are already in canon**: the Atashkadeh (fire temple) *burns back* the Shadow Zone within a radius. Iran's Farr-generating buildings double as shadow-pushers. **The cosmological war becomes literal map-painting.**
- Divs units inside the Shadow Zone gain combat bonuses; outside, they gain penalties (Aulad's "weakest at noon" — light is canonically anti-Div).

**How it differs from Iran.** Iran's economy is point-source (mines, farms). Divs' economy is **area-source**. Iran wins by holding economy points; Divs win by *expanding the surface area of corruption*. The maps become contested in two layers: tactical (units fighting) and cosmological (Shadow vs. Fire painting the ground).

**Tradeoffs and balance implications.**
- Visually stunning — possibly the single most readable "this is a different faction" effect in the game. A purple shadow creeping toward the Iranian fortress is *Shahnameh imagery*.
- Balance challenge: passive area resource generation is hard to tune. Too fast and Divs steamroll; too slow and they can't compete with Iran's deterministic economy.
- Pairs naturally with the existing Farr/Atashkadeh system. Iran's lore-anchor (the sacred flame) becomes Divs' direct counter — no new system needed on the Iran side.
- Risk: this can devolve into a passive game where Divs just turtle around their well and watch the map fill in. Counter-balance: the Shadow advances *only when actively defended*; if Iran units stand inside Shadow Zone unopposed, they push the boundary inward.

**Implementation difficulty.** **Medium to heavy.**
- Requires a **terrain-corruption grid layer** — separate from the existing fog-of-war data layer (Phase 3 of `02_IMPLEMENTATION_PLAN.md`), but architecturally similar. This is *not* a small system: it's a per-tile state with shader visualization, expansion logic on the simulation tick, and counter-effects from Iran's buildings.
- The shader work for the visible Shadow Zone is *the* art-direction risk on this proposal. Done well, it's iconic. Done badly, it looks like a fog-of-war bug.
- Does not require a new economy subsystem — the resource generation is a passive tick on a known area.

**Lore-fit grade: A.** Quotes Mazandaran-as-demon-zone, Zoroastrian counter-creation, and the Atashkadeh-vs-Shadow war directly. Probably the *most visually iconic* of the four proposals.

---

### Proposal D — The Brain-Tax (Zahhak's serpents)

**Lore basis.** Zahhak's two shoulder-serpents, daily fed the brains of two young men. The most famous "demonic economy" in the entire epic. Self-cannibalizing tyranny: Zahhak survives only by extracting from his own population every day. (Per Wikipedia and the Aga Khan Museum's Death-of-Zahhak entry.)

**Mechanical proposition.**
- Divs **start with a fixed economic engine that requires constant unit input.** A central building — call it the **Ma'bad-e Mar** (معبد مار, "Serpent-Temple") or invoke Zahhak's name directly: **Aiwan-e Zahhak** ("Zahhak's Hall") — generates resources at a high rate, *but* every N seconds it demands a **friendly Div unit be sacrificed at the altar.**
- If the sacrifice is met, the engine pumps out resources at superior rate (>Iran).
- If skipped, the engine *attacks the Divs player itself* — the serpents demand brains; deny them and they take from the master. Resource generation reverses (resources drain), the building's HP ticks down, and adjacent friendly units take damage.
- The Divs player's pop cap is not a constraint on army size — it's the *tax base*. A bigger cap means a bigger sacrificial pool.
- Lower-tier Div units (lesser divs, easily produced) are explicitly sacrificable; named Divs (Akvan, Arzhang, etc., as hero units) cannot be sacrificed — they are too valuable, and lore-wise, *Zahhak does not eat his own captains*.

**How it differs from Iran.** Iran's economy is steady-state. Divs' is *unstable* by design — a permanent forced choice every 30 seconds: *do I sacrifice a unit to keep the engine running, or do I save it for combat?* Every tactical decision is also an economic decision.

**Tradeoffs and balance implications.**
- Risk of being too fiddly. "Click the unit, click the altar, every 30 seconds" can become micromanagement hell. Mitigation: rally-point auto-sacrifice ("send next produced unit to altar") option.
- Strong snowball protection built in: if the Divs player's army is destroyed, the engine starves itself, the player collapses internally — *exactly* the Zahhak-falls-when-Kaveh-rises arc the epic describes. The economy mechanic *is* the lore arc.
- This is **the most narratively-coupled-to-the-Kaveh-Event** proposal. If the Iran player triggers the Kaveh Event, mechanically this resonates with Zahhak's collapse — Divs' brain-tax economy fails because the population revolts. Could even be unified: the Divs' "Kaveh moment" is when the brain-tax fails.

**Implementation difficulty.** **Light to medium.**
- One periodic timer on a building. Demands a unit. Eats the unit on success or damages adjacent owner units on failure.
- Auto-sacrifice rally-point requires standard rally-point handling, which the game already has in Phase 4.
- The hardest part is *tuning the cadence and the punishment severity* — and that is `BalanceData.tres`, not code.

**Lore-fit grade: A.** Direct Zahhak-quote. The most narratively legible of the four proposals — every Iranian player will instantly recognize the brain-tax.

---

## 2.3 Side-by-side comparison

| Mechanic | Lore anchor | Economic shape | Implementation | Snowball-protection built-in? |
|---|---|---|---|---|
| **A. Tributary Gulag** | Tahmuras / Aulad / Zahhak's coercion | Steal-and-bind workers from enemy | Medium | Yes (decay forces constant raiding) |
| **B. Devouring Hunger** | Az, parasitic creation | Kill = resource; no gathering | Light–medium | Yes (diminishing returns + Iran's Farr loss) |
| **C. Shadow-Spread** | Mazandaran, counter-creation | Passive from corrupted terrain area | Medium–heavy | Yes (Atashkadeh as direct counter) |
| **D. Brain-Tax** | Zahhak / shoulder-serpents | Sacrifice friendly units to a building | Light–medium | Yes (engine starves on collapse) |

## 2.4 Recommended hybrid

If Divs ship as a single coherent design rather than four mutually-exclusive options, the highest-leverage hybrid is **A as the spine + C as a passive layer**:

- **A (Tributary Gulag) is the active economy.** Capturers raid; bound captives gather; Bandkhaneh holds them. This gives the Divs faction a *clear gameplay verb* — raid, capture, bind. It maps cleanly onto Aulad's image and Tahmuras's reverse.
- **C (Shadow-Spread) is the passive layer.** A Dark Well at the start projects a slowly-creeping Shadow Zone. Inside the Zone, captures are easier (mortals weaken in shadow); the Atashkadeh burns it back. The Shadow becomes the *spatial expression* of where Divs are dominant — a map-readable thing.
- **D (Brain-Tax) becomes a Tier 3 / hero-tier mechanic.** Late-game, the Divs player can build the Aiwan-e Zahhak as an optional super-economic-engine that requires sacrifices. Powerful but high-risk. Mirrors the late-game Iranian Royal Court tier in flavor.
- **B (Devouring Hunger) becomes a single hero-aligned mechanic** — the Divs equivalent of Rostam's Cleaving Strike, an Az-themed ability for the Divs hero unit (Div-e Sepid himself, when he becomes a playable boss) that converts kills into instant Az-resource on a temporary basis.

This hybrid hits all four lore anchors without any single one carrying the whole faction's weight, and structures the mechanical complexity in a way that mirrors the Iran tier-up arc (early simple → mid-game options → late-game superstructure).

## 2.5 What this means for the MVP and post-MVP roadmap

- **MVP (current focus): unchanged.** Divs are not playable. Iran-vs-Turan ships first. The campaign may use Divs as a non-playable antagonist with simplified, scripted economy (or no economy, just spawned waves) — that's a campaign-mission concern, not a faction-design concern.
- **Post-MVP, Tier 2/3:** when Divs become playable, the design conversation should pick from this menu (or extend it). Whichever path is chosen, the faction's economy will be *materially different from Iran's and Turan's worker-and-farm loop*. That divergence is the point: **the Iran-Turan asymmetry is interesting; the Iran-Turan-Divs asymmetry should be revelatory.**
- **None of these mechanics block the MVP.** They are deliberately scoped so that the Iran/Turan side does not need to know about them — the existing Farr system, Atashkadeh, and combat triangle interact cleanly with all four proposals as proposed. Iran's design does not need retrofitting to support a future Divs faction.

---

## Sources cited

### Encyclopaedia Iranica
- [DĪV](https://www.iranicaonline.org/articles/div/) — primary scholarly entry on the div as a category
- [DĒW](https://www.iranicaonline.org/articles/dew/) — Middle Persian / Pahlavi-era continuation
- [ĀZ](https://www.iranicaonline.org/articles/az-iranian-demon/) — the demon of greed/devouring
- [AKVĀN-E DĪV](https://www.iranicaonline.org/articles/akvan-e-div-the-demon-akvan-who-was-killed-by-rostam/)
- [COSMOGONY AND COSMOLOGY i. In Zoroastrianism](https://www.iranicaonline.org/articles/cosmogony-i/)

### Wikipedia (sourced and citing primary scholarship)
- [Daeva](https://en.wikipedia.org/wiki/Daeva)
- [Div (mythology)](https://en.wikipedia.org/wiki/Div_(mythology))
- [Div-e Sepid](https://en.wikipedia.org/wiki/Div-e_Sepid)
- [Akvan Div](https://en.wikipedia.org/wiki/Akvan_Div)
- [Arzhang Div](https://en.wikipedia.org/wiki/Arzhang_Div)
- [Zahhak](https://en.wikipedia.org/wiki/Zahhak)
- [Tahmuras](https://en.wikipedia.org/wiki/Tahmuras)
- [Mazandaran (Shahnameh)](https://en.wikipedia.org/wiki/Mazandaran_(Shahnameh))
- [Rostam's Seven Labours](https://en.wikipedia.org/wiki/Rostam%27s_Seven_Labours)
- [Zoroastrian cosmology](https://en.wikipedia.org/wiki/Zoroastrian_cosmology)

### Museum and academic sources
- [The Death of Zahhak — Aga Khan Museum (Shahnameh of Shah Tahmasp)](https://collections.agakhanmuseum.org/collection/artifact/the-death-of-zahhak-akm155)
- [Rostam Slays the White Div — Fitzwilliam Shahnameh Project](https://shahnameh.fitzmuseum.cam.ac.uk/explore/objects/no-47-rostam-slays-the-white-div)
- [Rostam Binds the Black Div — Fitzwilliam Shahnameh Project](https://shahnameh.fitzmuseum.cam.ac.uk/explore/objects/no-101-rostam-binds-the-black-div)
- [Rustam Compels Aulad — RISD Museum](https://risdmuseum.org/art-design/collection/rustam-compels-aulad-lead-him-white-demon-17398)
- ["Of Monsters and Men: Humanity, Gender, and the Demonic in Ferdowsi's Shahnameh" — Association for Iranian Studies](https://associationforiranianstudies.org/content/monsters-and-men-humanity-gender-and-demonic-ferdowsi%E2%80%99s-shahnameh)
- [Smithsonian National Museum of Asian Art — Kay-Kavus](https://asia-archive.si.edu/learn/shahnama/kay-kavus/)
- ["Kay Kavus's War Against the Demons of Mazanderan" — Shahnameh Reading Project](https://imakeupworlds.com/index.php/2016/04/kay-kavuss-war-against-the-demons-of-mazanderan-shahnameh-reading-project-12/)
- ["The Akvan Div" — Shahnameh Readalong](https://imakeupworlds.com/index.php/2016/07/the-akvan-div-shahnameh-readalong-20/)
- ["Magic, Witches and Devils in the Persian Book of Kings" — Manchester Medieval Society](http://medievalsociety.blogspot.com/2015/12/guest-post-magic-witches-and-devils-in.html)

### Translations and primary text references
- The Dick Davis translation of the *Shahnameh* (Penguin, 2006) and the older Warner & Warner edition (1905) are the standard English sources for primary text. Per the user instructions and `00_SHAHNAMEH_RESEARCH.md` §7, these and the Khaleghi-Motlagh critical Persian edition are the canonical sources for any specific verse-citation work in subsequent design passes.

---

*End of research document. This is intended as a starting point for the future design-chat conversation about Divs as a playable faction. All mechanical proposals are non-binding; lore is verifiable.*
