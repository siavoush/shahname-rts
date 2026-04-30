# Shahnameh RTS — Research & Scoping Document

*A real-time strategy game drawn from Ferdowsi's Book of Kings.*
*Last updated: 2026-04-22*

---

## 0. Context

This is a pivot from an earlier Dune RTS concept. Its technical conclusions (Godot 4 engine, Claude Code workflow, stylized visuals, solo/no-budget framing) carry over verbatim to this project and are committed in `DECISIONS.md` and applied across `02_IMPLEMENTATION_PLAN.md` and `docs/ARCHITECTURE.md`. Read §10 of this document for the carry-over summary.

**What changed:** the setting. The material is now Ferdowsi's *Shahnameh* (*شاهنامه*), the Persian *Book of Kings*.

**Why it's a dramatically stronger starting position than Dune:**

1. **Public domain.** Composed c. 977–1010 CE. No Funcom, no Legendary, no estate. Free to use real character names, real place names, real mythology. The single biggest constraint of the Dune project — IP — simply does not exist here.
2. **Personal connection.** Siavoush's father used to spend an hour each night reading Shahnameh sections aloud, then retell them to him as bedtime stories. That is how he fell asleep as a child. His name itself is Siavoush — one of the Shahnameh's most important tragic figures. This project is, in some sense, a continuation of a father-to-son transmission made playable. Games made from that kind of inheritance land differently than games made from references.
3. **Underserved in gaming.** Several Persian-mythology games exist (see §9), but no RTS in the Command & Conquer / StarCraft / Age of Empires mold has ever been built on the Shahnameh. The slot is open.
4. **RTS-native material.** The Shahnameh is 50,000 couplets of battles, heroes, dynasties, and mythic creatures. It is almost *designed* to be an RTS. The Iran-Turan wars alone supply generations of faction conflict.
5. **Visually distinctive.** The Persian miniature tradition gives you a genre-differentiating art direction that's been underutilized in games. Instantly recognizable when done well.

---

## 1. The Source Material — a Primer

### Who was Ferdowsi

**Abolqasem Ferdowsi** (c. 940–1020 CE) was a Persian poet from Tus, in Khorasan (northeastern Iran). He spent roughly 30 years composing the *Shahnameh*, completing it around 1010 CE. He dedicated the work to Sultan Mahmud of Ghazni, who — by one famous account — underpaid him; Ferdowsi reportedly refused the meager reward and left Ghazni, though the story may be embroidered.

Ferdowsi's achievement is not only literary. He composed the *Shahnameh* in **pure Persian**, deliberately avoiding Arabic loanwords in a conscious act of cultural preservation during a post-conquest era when Arabic dominated learned writing. Iranians credit Ferdowsi with *saving the Persian language itself*. His line — *بسی رنج بردم در این سال سی / عجم زنده کردم بدین پارسی* ("I endured great toil during these thirty years / I revived the Persian people with this Persian") — is a cultural touchstone across the Persianate world.

### The work

**~50,000 couplets (bayts)**, making it one of the longest epic poems ever written — roughly twice the combined length of the *Iliad* and *Odyssey*.

It narrates the mythical and semi-historical past of Greater Iran from the creation of the world to the Arab conquest of the Sasanian Empire in 651 CE, spanning roughly 50 rulers across three ages.

It is the national epic of **Iran, Afghanistan, and Tajikistan**, and is honored across the broader Persianate cultural sphere. Annual festivals (*Shahnameh-khani*, recitation gatherings) keep the living tradition alive.

### Tonal palette

The *Shahnameh* is simultaneously:
- Mythic and magical (demons, dragons, a benevolent giant bird, 900-year-old heroes)
- Tragic (Rostam unknowingly kills his own son; Siavoush, the noblest prince, is murdered by treachery)
- Political (dynastic succession, the divine right of kings, what separates just rule from tyranny)
- Martial (battles, duels, sieges, armies)

A Shahnameh RTS does not have to pick one of these registers — ideally it holds all four. The epic tone is what makes the material work.

---

## 2. The Three Ages

The *Shahnameh* divides into three clear "ages," and the choice of which to build in is the single most important design decision after engine selection.

### Pishdadian — the Mythological Age

The primordial age. The world is young, kings are semi-divine, demons walk openly, and cosmic forces shape history.

**Key rulers and figures:**
- **Keyumars** — the first king, a shepherd figure who wore leopard skins
- **Hushang** — discovers fire; the Nowruz new year festival traces here
- **Tahmuras Divband** — "Binder of Demons," learns writing from captured divs
- **Jamshid** — the golden-age king who invents crafts, calendars, and civilization. His pride destroys him; the *farr* (divine glory) departs him and he is overthrown
- **Zahhak** — an Arab prince corrupted by the evil Ahriman, who grows twin serpents on his shoulders that must be fed the brains of two young men every day. He rules a millennium of tyranny
- **Kaveh the Blacksmith** (Kaveh Ahangar) — an ordinary blacksmith who lost 17 sons to Zahhak's serpents. He raises his leather apron on a spear as a banner of revolt — this becomes the **Derafsh-e Kaviani**, the ancient Persian royal standard
- **Fereydun** — defeats Zahhak and chains him forever beneath Mount Damavand. Divides the world among his three sons: **Salm** (west/Rum), **Tur** (east/Turan), and **Iraj** (center/Iran). Salm and Tur murder Iraj out of jealousy — **the origin of the Iran vs. Turan conflict that drives the rest of the epic**
- **Manuchehr** — Iraj's avenger, first to wage war against Turan

**RTS fit:** Strongest "good vs. evil" dramatic arc (Fereydun/Kaveh vs. Zahhak). Most magical and creature-rich. Excellent campaign material but less recognizable character roster than the heroic age.

### Kayanian — the Heroic Age (the heart of the Shahnameh)

The legendary era of Iran's greatest heroes and bitterest wars. Most Persians, when they say "Shahnameh," mean this age.

**Kings of Iran:**
- **Kay Kobad** — first Kayanian king
- **Kay Kavus** — reckless, ambitious, often disastrous; famously attempts to fly to heaven in a chariot pulled by eagles
- **Kay Khosrow** — Siavoush's son, the ideal just king; eventually renounces the throne and walks into the mountains
- **Goshtasp** — patron of Zoroaster in the Shahnameh's telling
- **Bahman**, **Homay**, **Darab**, **Dara** — later Kayanians, bridging toward the historical age

**The Pahlavans (heroes/champions):**
- **Zal** — raised by the Simurgh after being abandoned on a mountainside as an infant; later wins Rudaba of Kabul; father of Rostam
- **Rostam** — the supreme hero of the entire epic. A warrior of ~900 years' lifespan, son of Zal and Rudaba. Performs the **Seven Labors (Haft Khwan)** to rescue Kay Kavus from the White Div in Mazandaran. Kills his own son Sohrab in unknowing single combat. Later kills the prince Esfandiyar with guidance from the Simurgh. Finally dies by treachery, pulled into a pit of spears by his half-brother Shaghad
- **Rakhsh** — Rostam's legendary mount, a divine horse inseparable from the hero
- **Esfandiyar** — Goshtasp's son, invulnerable to weapons after bathing in a sacred fire; killed by Rostam with an arrow to the eye (his one vulnerable spot)
- **Giv**, **Bijan**, **Gurdafarid** (a famous female warrior who duels Sohrab), **Gordie** — the broader supporting cast of heroes

**Turan and its champions:**
- **Afrasiyab** — King of Turan, the great antagonist; rules for centuries
- **Piran Viseh** — Afrasiyab's wise counselor, one of the most sympathetic Turanian characters
- **Piltan**, **Houman**, and many Turanian warriors

**Siavoush's tragedy:**
- **Siavoush** — Kay Kavus's son, raised by Rostam, morally pure. His stepmother Sudabeh falsely accuses him. He undergoes trial by fire to prove his innocence, then flees to Turan. Afrasiyab betrays and murders him. Siavoush's death is the central crime of the epic; blood revenge for Siavoush motivates the next generation's wars and culminates in Kay Khosrow's conquest
- **Farangis** — Siavoush's Turanian wife and Kay Khosrow's mother

**Supernatural figures:**
- **Simurgh** — the divine/benevolent giant bird who lives on Mount Alborz; raised Zal, aided Rostam and Esfandiyar
- **Div-e Sepid** (The White Div) — the supernatural ruler of Mazandaran, defeated by Rostam in the seventh labor
- **Akvan Div** — a whirlwind demon
- **Arzhang Div** and other named demons
- **Dragons** (azhdaha) encountered throughout

**RTS fit: maximum.** This era is why every Shahnameh-curious person eventually picks it. Iran vs. Turan is a natural two-faction core; divs as a third faction fill out the design. Siavoush's story gives the user a personal through-line. Rostam's Seven Labors is a pre-written 7-mission campaign that Ferdowsi himself outlined a thousand years ago.

### Sasanian — the Semi-Historical Age

The epic transitions from myth into semi-historical narrative, closing with the fall of the last Persian Empire.

**Key figures:**
- **Sekandar** — Alexander the Great, presented as a half-Persian king
- **Ardashir Babakan** — founder of the Sasanian dynasty
- **Bahram Gur** — warrior-king famous for hunt scenes
- **Anushirvan the Just** (Khosrow I) — archetype of the just ruler
- **Bahram Chobin** — usurper-general
- **Khosrow Parviz and Shirin** — the great royal love story (later expanded by Nezami)
- **Yazdegerd III** — last Sasanian emperor, defeated by the Arab conquest at the battles of al-Qadisiyyah and Nahavand (636 and 642 CE). The epic ends with Persia's fall

**RTS fit:** Grounded, historical, Age-of-Empires-adjacent. Less mythic. Strong material for a *sequel* or historical campaign expansion, but not where a first Shahnameh RTS should start — you'd lose the mythic register that differentiates the project.

### Recommendation: Kayanian / Heroic Age

Start here. Every arrow points to it.

Suggested campaign structure: an arc from **Kaveh's revolt against Zahhak** (closing out the mythological age) through the **wars for Siavoush's blood** and **Kay Khosrow's final victory over Afrasiyab** (culminating the heroic age). That's ~15 missions of pre-written narrative, with natural escalation from mortal-vs-tyrant to dynastic war to final reckoning.

---

## 3. Faction Design Space

### The natural core: Iran vs. Turan

Two factions are built into the source material. The entire heroic age is a war between them.

**Iran** — settled, agrarian, kingly. Centered on the Iranian plateau. Champion-driven warfare led by heroic pahlavans. Persian cavalry, heavy armored infantry, legendary archers (the Parthian shot is real military history), war elephants (Sasanian). Visual palette: gold, crimson, lapis blue. Architectural reference: Persepolis, Parthian/Sasanian stonework.

**Turan** — nomadic-steppe culture. Swift cavalry, horse archers, raiders. Broader, looser armies built on mobility. Visual palette: cool blues, silver, fur, leather. Architectural reference: steppe yurts, Scythian-style goldwork.

This is a natural asymmetric 2-faction design: **Iran trades speed for durability and champion power; Turan trades armor for mobility and numbers.** It maps cleanly to familiar RTS asymmetry (GDI vs. Nod, Terran vs. Zerg) while grounding both sides in historically-attested military cultures.

### Third faction(s)

- **Divs (demons)** — supernatural horror faction. Works as a campaign-only antagonist, a neutral environmental threat, or a third playable faction with bizarre mechanics (corruption, possession, summon-from-the-earth). Boss-tier: Div-e Sepid, Akvan Div, Zahhak's serpent legions.
- **Mazandaran** — a distinct region of demon-haunted terrain, essentially a lawless zone where Rostam's Seven Labors occur. Can be faction or campaign territory.
- **Rum** (West / Byzantium / Salm's inheritance) — Western power, intermittent rival or ally. Good late-campaign or expansion material.
- **Hind** (India / East) — allies and rivals to the east. Good for trade-and-diplomacy mechanics.
- **Tazi** (Arabs) — mainly relevant in the Sasanian-era closing. Out of scope for a Kayanian-age game.

**MVP recommendation:** **Iran + Turan playable, Divs as campaign antagonist** (not initially playable). Post-launch DLC could make Divs playable or add Rum/Hind. Starting with three playable factions on day one is the classic solo-dev overreach.

---

## 4. Unit Archetypes Drawn from the Epic

These are suggestive rather than prescriptive — the point is that the source material supplies unit designs without any need for invention.

### Iran

| Unit type | Shahnameh grounding | Design notes |
|---|---|---|
| **Pahlavan** (Hero) | Rostam, Esfandiyar, Giv, Bijan — named heroes with distinct abilities | Small number of named hero units, each mechanically distinct, respawning on delay. Rostam as the "ultimate" unlock |
| **Savar / Savaran** (Knight/Cavalry) | Armored Iranian cavalry, core of Sasanian military | Balanced melee cavalry, strong vs. infantry |
| **Kamandar** (Archer) | Persian/Parthian archery was legendary in the ancient world | Ranged infantry; consider a "mounted archer" variant for horse archery |
| **Piyade** (Infantry) | Spear-and-shield line infantry | Cheap, numerous, formation-dependent |
| **Pil** (War elephant) | Attested in later Sasanian armies | Heavy siege/anti-cavalry |
| **Atashban** (Fire-bearer / Zoroastrian) | Fire as sacred and martial element in pre-Islamic Iran | Specialist siege/anti-building — handle with religious sensitivity |
| **Simurgh** | The divine bird of Mount Alborz | Faction-defining "called" super-unit; appears briefly to turn a battle |

### Turan

| Unit type | Shahnameh grounding | Design notes |
|---|---|---|
| **Horse archer** | Steppe/Scythian/Parthian military tradition | Fast, harassing, core identity unit |
| **Steppe heavy cavalry** | Afrasiyab's armored riders | Slower elite cavalry |
| **Raider** | Light skirmisher infantry | Cheap, fast, weak |
| **Azhdaha-rider** (Dragon rider) | Mythic units — more speculative | Late-game mythic unit |
| **Turanian champion** | Piran, Houman, and named Turanian warriors | Hero-tier, parallel to Iranian pahlavans |

### Divs / Mazandaran

| Unit type | Shahnameh grounding | Design notes |
|---|---|---|
| **Div-e Sepid** (White Div) | Boss of Rostam's 7th labor | Campaign boss |
| **Akvan Div** | Whirlwind demon | Boss or summoned unit |
| **Serpents of Zahhak** | Zahhak's shoulder-serpents | Swarm unit |
| **Dragons** | Multiple dragons across the epic | Boss/rare unit |
| **Lesser divs** | Named and unnamed demons throughout | Basic supernatural infantry |

---

## 5. Iconic Mechanics Drawn from the Epic

These are design possibilities unique to the Shahnameh's setting. Pick two or three and build the game around them — don't try to implement all of them.

### 1. Derafsh-e Kaviani — the morale banner

Kaveh's leather-apron banner is the ancient Iranian royal standard and one of the most resonant symbols in the epic. Mechanically: a banner unit or building that radiates morale/buffs to nearby units. Loss of the banner is a serious setback. **Why it matters:** rooted in the source, visually distinctive, gives the player a meaningful tactical asset to protect.

### 2. Pahlavan duels — single combat

Persian epic tradition has *mard-o-mard* (champion combat) — armies stop and send champions to fight before/instead of the whole battle. Mechanically: when two hero units engage, nearby units pause; winner's side gets a morale surge. Or: an optional pre-battle duel mini-phase where you can offer/accept a champion fight. **No other RTS has this mechanic.** It's a signature feature.

### 3. Farr-e Izadi — divine glory as a game mechanic

The *farr* (*خرمن کیانی*) is the divine charisma that legitimizes kings in the Shahnameh. When a king acts unjustly, the farr departs, and his rule collapses. Mechanically: hero-units have a *farr* meter affected by their actions (justice/injustice). Lose farr → your army's morale, unit production, and abilities degrade. Regain it by moral actions. **Why it matters:** this is the Shahnameh's explicit political philosophy made playable. Makes "how you win" matter, not just "whether you win."

### 4. Seven-Labors campaign structure

Rostam's Haft Khwan — the Seven Labors — are seven distinct trials with seven distinct mechanical challenges. Lion, desert, dragon, sorceress, warrior-king, demon captain, White Div. A single-hero campaign arc naturally structured as seven missions, each a different RTS challenge (survival, pathing, puzzle-combat, resource-scarcity, etc.). **Why it matters:** pre-written campaign of seven missions with mechanical variety already built in.

### 5. Mazandaran — the demon-haunted zone

A specific region where mortal rules break down. Divs spawn, farr decays faster, normal units suffer penalties. Creates a distinct *tactical biome* beyond "open/forest/mountain."

### 6. Nowruz and the year cycle

The Persian calendar is explicitly embedded in the Shahnameh (Jamshid invented Nowruz). A yearly cycle affects the map: spring brings growth and reinforcements, winter slows everything. Could be purely cosmetic or mechanically meaningful.

### 7. Prophetic dream phases

Shahnameh kings constantly seek counsel from dreams and wise men (*moaberan*). A dream/prophecy phase at the start of each mission that hints at enemy plans but is poetically ambiguous. Gives flavor and soft strategic information.

---

## 6. Art Direction — the Persian Miniature Tradition

This is a strategic asset, not a constraint. Persian miniature painting gives you a visual language that:
- Is instantly recognizable as "Persian epic" to anyone who has seen it
- Has been refined over ~800 years of tradition (Timurid, Safavid, Qajar periods)
- Is uniquely underutilized in games (Hindu mythology has *Raji*, Japanese has dozens, Greek has *Hades* — Persian miniature has essentially none)
- Maps naturally to a stylized, readable RTS art style

### Visual principles to carry into the game

| Miniature principle | How it translates to RTS visuals |
|---|---|
| **Flat/layered perspective** — no single vanishing point | Top-down or low-angle isometric camera. Foreground/midground/background as distinct color bands |
| **Rich saturated palette** — lapis blue, gold, crimson, turquoise | Strong faction color coding. Iran = gold/crimson; Turan = steel blue/silver; Divs = purple/black; Mazandaran = violet/green |
| **Gold leaf highlights** | Particle effects and special-unit auras use gold sparingly for impact |
| **Pattern-rich surfaces** — tilework, textiles, calligraphy | Buildings, banners, and UI borders carry pattern motifs. Background terrain as pattern, not photoreal texture |
| **Stylized figure proportions** | Distinct, readable unit silhouettes. Heroes are visually larger than regular units (pictorial hierarchy) |
| **Landscapes as decorative elements** | Mountains, rivers, trees as stylized shapes with strong silhouettes, not simulated naturalism |

### Reference games (for *feel*, not copying)

- **Hades** — deep stylistic commitment to a specific mythological aesthetic
- **Raji: An Ancient Epic** — Hindu mythology, South Asian miniature-adjacent style; closest aesthetic relative
- **Bad North** — minimalist silhouettes, strong color, RTS readability
- **Tooth and Tail** — 2D isometric RTS with strong art direction
- **Kena: Bridge of Spirits** — stylized mythological indie
- **11-11 Memories Retold** — brush-stroke-style rendering

### Reference resources for Persian miniature

- **The Houghton Shahnameh** (Shah Tahmasp's Shahnameh, c. 1520s) — the most famous illustrated Shahnameh; 258 miniatures, the gold standard visual reference
- **The Demotte Shahnameh** (c. 1335) — earlier, more gestural style
- **Safavid miniatures** — 16th century, height of the tradition
- Contemporary artists working in the tradition: Ardeshir Mohassess, Farah Ossouli, and others
- **Metropolitan Museum online collection** — free high-resolution images of major miniatures

You will essentially be doing **Shah Tahmasp's Shahnameh, playable.**

---

## 7. Cultural Authenticity — What "Doing This Right" Means

Given the heritage connection, this is not optional; it's the project's foundation. Getting this wrong is worse than not doing it — it erodes trust with the audience most likely to champion the game. Getting it right is the game's strongest moat.

### Source rigor

- **Primary source**: Jalal Khaleghi-Motlagh's critical Persian edition is the scholarly gold standard.
- **English**: Dick Davis's translation (Penguin) is the best modern English rendering. Warner & Warner (1905) is the older complete edition (public domain, online).
- **Scholarship**: Djalal Khaleghi-Motlagh's writings; Olga Davidson (*Poet and Hero*); Mahmoud Omidsalar. *Encyclopaedia Iranica* entries for individual Shahnameh characters are the quick-reference standard.

### Naming and transliteration

Use consistent standard transliteration — Rostam (not "Rustem"), Afrasiyab (not "Afrasyab"), Kay Khosrow (not "Kai Khosrow" or anglicizations). Include original Persian spellings (رستم, افراسیاب, کیخسرو) in a codex/glossary. Plan for a **bilingual UI option** (Persian/English) — this will mean the world to the Iranian diaspora audience and is technically not a large lift in Godot.

### Iran vs. Turan — handle with care

The epic's Iran-vs-Turan framing is not modern Iran vs. modern Turkic peoples, but modern Turkic-heritage audiences often identify with Turan. Ferdowsi himself gives Turanian heroes (Piran, Agrirath) dignity and depth; Afrasiyab is cunning and cruel, but he is a king, not a monster. **Design Turan as worthy rivals, not cartoon villains.** Reserve cartoon villainy for the divs and Zahhak, who are the proper supernatural evils of the epic.

### Religious and philosophical respect

The Shahnameh is culturally Zoroastrian in its setting (the heroic age predates Islam). Fire, the *farr*, the concept of cosmic balance — these carry religious weight for modern Zoroastrians, a small surviving community. Handle fire temples, sacred flame imagery, and Zoroastrian symbology with respect; don't caricature for Western fantasy aesthetics. Consult with Zoroastrian community resources before finalizing any religious imagery.

### Community engagement before launch

- Post early devlogs in Persian and English.
- Engage with Iranian-diaspora gaming communities, Shahnameh-khani groups, and Iranian-studies academic networks well before launch.
- Consider an advisory role for a Shahnameh scholar (could be as light as email consultations).
- The *Shahnameh-khani* tradition — public recitation — is living culture. Respecting it positions the game as an extension of that tradition, not an appropriation of it.

### Political neutrality

Modern Iranian politics (Islamic Republic, diaspora factions, regional rivalries) are a minefield. The Shahnameh itself is celebrated across the political spectrum and across Iranian/Afghan/Tajik lines. **Keep the game at the level of the ancient epic.** Don't let contemporary political references leak in. This is both ethically correct and commercially wise — your audience includes Iranians of every political stripe, and the epic is the common ground.

---

## 8. Market Positioning

### The gap you're filling

There are Persian-mythology games. None is an RTS in the Command & Conquer / SC2 / Age of Empires mold on the Shahnameh. You are filling a real, identifiable gap.

### Prior art to acknowledge (and differentiate from)

| Game | Studio | Genre | Relationship to your project |
|---|---|---|---|
| **Garshasp: The Monster Slayer** (2011) | Dead Mage (Iran) | Action hack-and-slash | Sibling project — proves audience exists. Different genre |
| **Garshasp: Temple of the Dragon** | Dead Mage | Action sequel | Same as above |
| **Seven Quests** (announced 2015) | Various | Online multiplayer | Unclear current status; Rostam-centric |
| **First Blood: Persian Legends** | — | Real-time tactics, Sasanian era | **Closest competitor.** Different era (historical, not heroic), different sub-genre (tactics, not strategy) |
| **Gordokht** | — | Souls-like, Shahnameh-inspired | Demo 2025. Different genre |
| **ZAHAK** | — | Roguelike action | Different genre |
| **Persian Empire Builder** | — | 4X / city builder | Different genre, historical-realist not mythic |

**Positioning statement (draft):** *"The first real-time strategy game set in the world of Ferdowsi's Shahnameh. Command the heroes of Iran against the forces of Turan and the demons of Mazandaran, across a campaign drawn from the Persian Book of Kings."*

### Target audiences (in decreasing priority)

1. **Iranian and Iranian-diaspora players** (~10M diaspora, large domestic gaming market) — the core audience who will care most and champion hardest.
2. **Broader Persianate audiences** — Afghans, Tajiks, Uzbeks, Central Asian Turkic peoples (especially if Turan is respectfully drawn).
3. **RTS genre veterans** — the audience that played AoE, C&C, SC2 and is hungry for serious new RTS titles after a genre drought.
4. **Players of culturally-specific mythic games** — the *Hades*, *Raji*, *Never Alone* audience who will try mythology-grounded indies sight-unseen.

### Steam tagging strategy (when you get there)

Primary tags: `Strategy`, `Real Time Strategy`, `Mythology`, `Historical`, `Indie`. Secondary: `Stylized`, `Story Rich`, `Persian`, `Middle Eastern`. The "Persian" / "Middle Eastern" tags will be uncrowded — good for discovery.

---

## 9. Technical Decisions (Carry-Over from Dune Research)

These were worked out in the previous (archived) Dune research doc. They transfer directly:

- **Engine**: Godot 4. Text-file-native architecture is ideal for a Claude Code workflow. GDScript matches Python background. MIT license — zero royalties forever, which matters more than ever because this project's upside is now clearer.
- **Workflow**: Claude Code as primary development environment. Project expressed as plain-text files (.gd, .tscn, .tres) that Claude can read and edit directly.
- **Visual approach**: Stylized, not photorealistic. 2.5D isometric is the pragmatic starting point (natural fit for Persian miniature's flat perspective); stylized 3D with rotatable camera is the more ambitious option. Decide at prototype stage.
- **Platform**: PC desktop. Steam as primary distribution.
- **Scope framing**: Solo dev, no asset budget, first game. Tier 0 technical prototype → Tier 1 vertical slice → Tier 2 demo → Tier 3 full release. Realistic solo timeline: 2.5–6 years.
- **Licensing**: Godot MIT; no engine royalties. Setting is public domain.

The engine commitment is in `DECISIONS.md`; the tier structure is built into `02_IMPLEMENTATION_PLAN.md`'s phased plan and `docs/ARCHITECTURE.md`'s subsystem build state.

---

## 10. Scope Recommendations (Shahnameh-Specific)

### Tier 0 — Technical prototype (2–3 months)

Goal: prove the engine works for your core RTS loop.
- One map: a plain stylized field
- One unit type (a savar, because cavalry RTS movement is visually satisfying fastest)
- Click-to-move, basic pathfinding, basic attack
- No heroes, no factions, no spice — just "two armies of cavalry find each other and fight"
- Ship to itch.io free. Deadlines force completion

### Tier 1 — Vertical slice (6–12 months after Tier 0)

Goal: prove the **design** works.
- One playable faction (Iran) with ~6 unit types including one hero (Rostam)
- One AI opponent faction (Turan)
- One battle map, probably inspired by the plains of Khorasan
- Core loop: gather resources, build units, field an army, defeat the opponent
- **One signature mechanic implemented**: Pahlavan duels or the Derafsh banner — whichever you find more interesting
- Persian miniature aesthetic applied end-to-end, even roughly
- This is the Kickstarter/publisher/wishlist artifact

### Tier 2 — Demo (6–12 months after Tier 1)

- Both factions (Iran + Turan) playable
- 3 skirmish maps
- First 3 missions of a campaign — the Kaveh/Zahhak opening arc
- Persian + English language options in place
- Steam page live; Next Fest demo

### Tier 3 — Full release (12–24 months after Tier 2)

- Iran + Turan balanced
- Divs as campaign antagonist (non-playable)
- 12–15 mission campaign: Kaveh → Rostam's Seven Labors → Siavoush → Kay Khosrow's war
- 6–8 skirmish maps
- Skirmish AI at 2–3 difficulties
- Multiplayer probably scoped out of v1.0 (high risk/low necessity for a story-forward RTS)
- Steam launch

Total realistic timeline, solo, nights-and-weekends: **4–6 years.** Full-time: **2.5–4 years.**

---

## 11. Immediate Next Steps

1. **Read (or re-read) the Shahnameh**, at least Dick Davis's abridged English translation. This is a month of reading at a normal pace; you will reference it continuously. If you're already deep in the material from personal background, just spin up a scholarly edition as ongoing reference.
2. **Write a setting bible** as `01_SETTING_BIBLE.md` — which era you're in, which characters you're featuring, which events drive the campaign, what the map of your game-world looks like. Even if it's rough, getting it on paper forces decisions.
3. **Install Godot 4** and complete the official 2D and 3D tutorials (one weekend).
4. **Build a throwaway mini-RTS** (not Shahnameh-related) for 2–4 weeks. The goal is engine fluency, not a keepable codebase.
5. **Decide 2.5D isometric vs. stylized 3D** before Tier 1.
6. **Set up a Steam page** at Tier 1 to begin wishlist collection early.
7. **Keep the design bible** as one markdown file per faction/mechanic/lore element in this repo. Claude Code will be more useful in proportion to how well you document intent.

---

## 12. Open Questions

Before we write the setting bible, a few things to resolve:

- **Which campaign arc?** Kaveh-through-Kay-Khosrow is the full epic. A narrower arc (just Rostam's Seven Labors, just Siavoush's tragedy) is more achievable for a solo MVP. Your call.
- **Persian language priority — day one or later?** Including Persian language at the start is cheaper than retrofitting; I'd recommend starting bilingual, even if rough.
- **Folder rename?** The repo is currently at `.../Dune RTS/`. Want to rename it now to reflect the pivot, or leave it until more commitment is visible?
- **Who else should you show this to?** The concept of a Shahnameh RTS will resonate intensely in Iranian cultural communities. Early feedback from a small trusted audience (friends, family, a Shahnameh-khani group if you know one) would sharpen the concept before more code gets written.

---

*End of research document v1. The technical foundation is settled; the creative foundation is what we build next.*
