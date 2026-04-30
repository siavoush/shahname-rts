# Concept Art Prompts

A growing collection of prompts for image generators (OpenAI gpt-image / Midjourney / Flux / Stable Diffusion) to test visual direction. These are concept exploration only — none of this art will ship in the game. The goal is to iterate quickly on what the Persian-miniature-RTS aesthetic *feels* like before committing to a real pipeline.

Each prompt is dated, named, and annotated with what we were trying to learn from it.

---

## 2026-04-23 — `gameplay_001_kayanian_village_defense`

**Goal of this prompt:** First test of the visual direction. Establish whether "RTS gameplay screen rendered as a Safavid Persian miniature" is even a coherent concept the model can produce. Whether the proportions read as gameplay (high-angle, multiple readable units, UI overlay) while the style holds Persian-miniature integrity.

**Best for:** OpenAI gpt-image-1 (in ChatGPT or via API), or any model that follows long natural-language descriptions well. Notes for adapting to Midjourney follow the prompt.

### Prompt (paste this)

```
A gameplay screen from a real-time strategy game inspired by Ferdowsi's Shahnameh, rendered entirely as a 16th-century Safavid Persian miniature painting. High-angle three-quarters isometric view of a battlefield in the foothills of the Alborz mountains.

Foreground left: an Iranian village. Flat-roofed cream-walled houses with arched cobalt-blue doorways. A small gold-domed Atashkadeh (Zoroastrian fire temple) at the village center with a single sacred flame burning atop it. Cultivated wheat fields in rich saffron yellow surround the village, with two peasant workers in plain brown tunics gathering grain. A curving turquoise river runs through the scene, lined with slender dark-green cypress trees and pomegranate trees in red bloom.

Mid-ground: an Iranian battle line defending the village. Pahlavan foot soldiers in lamellar scale armor and conical helmets, carrying round shields painted with the Faravahar symbol; mounted archers in pointed caps drawing curved bows. At the center, the hero Rostam: a powerful broad-shouldered figure in a tiger-pelt cloak (the babr-e bayan) and gold helmet, riding Rakhsh his chestnut stallion, raising a curved sword above his head — clearly the visual focal point.

Background: Turanian raiders sweeping in from the upper-right on horseback, in steppe-nomad clothing, with red and black banners showing horse motifs. Beyond them, snow-capped Alborz mountain peaks painted in cool blues and silver. A small flock of birds circles overhead.

Style: traditional Persian miniature. Flat perspective with no Western vanishing point. Gold-leaf highlights on weapons, helmets, and the temple dome. Fine black ink linework defining every figure and architectural element. No cast shadows. Jewel-tone palette dominated by lapis lazuli blue, vermilion red, saffron yellow, emerald green, and burnished gold. Each figure occupies its own clear silhouette. A decorative ornamental border surrounds the entire image with interlocking Islamic geometric patterns in gold and indigo.

Game UI overlay across the top of the image: a thin gold band showing two small icons (a coin and a wheat sheaf) with numbers next to them, and a horizontal status bar labeled "FARR" filled approximately 65% with a luminous golden-green color. A small minimap in the bottom-right corner.

Aspect ratio 16:9, cinematic gameplay screenshot.
```

### Midjourney variant (compressed)

Midjourney v6/v7 tends to dilute long prompts. Use this instead:

```
gameplay screenshot of an RTS based on Ferdowsi's Shahnameh, rendered as a 16th-century Safavid Persian miniature painting, high-angle isometric view of an Iranian village in the Alborz foothills, flat-roofed cream houses, gold-domed fire temple with sacred flame, saffron wheat fields, turquoise river, cypress trees, Pahlavan warriors in lamellar armor defending against Turanian horseback raiders, hero Rostam at center in tiger-pelt cloak on chestnut horse Rakhsh, snow-capped peaks behind, flat perspective, gold leaf highlights, fine ink linework, no shadows, lapis blue and vermilion and saffron and gold palette, ornamental geometric border, thin game UI band at top with resource icons and a FARR meter, minimap in corner --ar 16:9 --style raw --v 7
```

### What to look for when you get the result

- **Style coherence**: does it actually read as Persian miniature, or did the model default to generic "fantasy painting"? If the latter, push harder on Safavid / 16th-century / Behzad references in the prompt.
- **Gameplay legibility**: can you tell at a glance there's a village, units, two factions, and a UI? If not, the camera angle or unit density is off.
- **Rostam recognizability**: is he clearly the centerpiece? The tiger-pelt and the horse should make him pop.
- **What's wrong**: anachronisms (Western fantasy armor instead of lamellar), missing UI, perspective gone Western, Rostam looks generic. Note these and iterate.

### Iteration notes (filled 2026-04-23 after generation)

**Result:** Stunning image. Style coherence excellent — model held the Safavid miniature aesthetic without drifting to generic fantasy. Gold-leaf details, ornamental border, Faravahar shields, Atashkadeh dome, Rostam in tiger-pelt cloak — all rendered as intended. UI overlay (gold band with coin/grain icons + FARR meter + minimap + command buttons) integrated more cleanly than expected.

**The problem:** Camera angle is cinematic / ground-level, not gameplay. Heroes posed dramatically at unit-eye height, deep horizon, individual figures painted with character. You can't manage 40 units from this angle — units occlude each other, terrain isn't readable from above, click targeting would be a nightmare.

**The reframe:** This is a *cinematic / menu / promotional* asset, not a gameplay view. RTS games standardly maintain two visual tiers: in-game (top-down or isometric, optimized for readability) and out-of-game (cinematic, optimized for emotional impact). We just confirmed that the project's promotional/menu aesthetic works. Now we need to test the gameplay aesthetic separately.

**Saved as:** main-menu / loading-screen / mission-briefing / Steam-page concept reference. Do not throw away.

**Next test:** see `gameplay_002_isometric_battlefield` below — same world, playable camera.

---

## 2026-04-23 — `gameplay_002_isometric_battlefield`

**Goal of this prompt:** Test whether the Persian-miniature style holds up at a true gameplay camera angle (high-angle isometric, ~45 degrees from vertical, like Age of Empires II or StarCraft II). The 001 image was beautiful but unplayable — this one needs to look like a screen you'd actually click on.

**Best for:** OpenAI gpt-image-1 first; Midjourney variant follows. Image generators *strongly* default to dramatic ground-level views for "epic battle" prompts. The prompt has to push hard on the camera language.

### Prompt (paste this)

```
A gameplay screenshot from a real-time strategy game inspired by Ferdowsi's Shahnameh, rendered in the style of a Safavid Persian miniature painting. CRITICAL CAMERA INSTRUCTION: this is a top-down high-angle isometric view, the camera positioned HIGH ABOVE the battlefield looking down at approximately 45 degrees from vertical. Think Age of Empires II or StarCraft II camera angle — the entire battlefield laid out below the viewer like a tabletop wargame, with every unit visible from above. This is NOT a ground-level cinematic shot, NOT a horizontal hero-pose composition. The viewer is looking DOWN at the battlefield.

The battlefield fills a wide rectangular play area. Approximately 30 small units are visible total, each clearly distinct but small in scale — no single character dominates the view.

Bottom-left quadrant: an Iranian village seen from above. Five flat-roofed cream-walled houses arranged around a small plaza, their flat rooftops visible as the topmost surface. A gold-domed Atashkadeh fire temple at the village center, dome visible from above with a sacred flame on top. Wheat fields painted as flat saffron-yellow patches with two tiny worker figures in brown tunics cutting grain. A turquoise river curves diagonally across the lower portion of the battlefield, lined with miniaturized cypress and pomegranate trees rendered as small icons.

Center: Iranian battle formation viewed from above. Three or four ranks of small Pahlavan soldiers with round shields painted with the Faravahar symbol — you can see the tops of their helmets and shields. Two units of horse archers on the flanks. The hero Rostam visible as a slightly larger figure in a tiger-pelt cloak on his chestnut horse Rakhsh, central but in proper scale with the other units (just slightly bigger, with a faint golden glow around him for readability — he is NOT towering or dramatically posed).

Upper-right quadrant: a Turanian raider army advancing, also viewed from above. Approximately 15 horseback figures in steppe armor, with small red and black horse-motif banners. They occupy roughly equal screen real estate to the Iranian forces. Empty open ground separates the two armies — the battle hasn't joined yet.

Background (only the top thin strip of the image): a band of snow-capped Alborz mountain peaks rendered small to indicate distance. The mountains occupy no more than 10% of the vertical image height.

Style: traditional Persian miniature aesthetic preserved despite the top-down angle. Flat colors, gold-leaf highlights on weapons and the temple dome, fine ink linework. NO cast shadows. Jewel-tone palette (lapis blue, vermilion, saffron, emerald, gold). Each unit and building reads with a clear silhouette from above. Decorative ornamental gold-and-indigo border around the entire image with Islamic geometric patterns.

UI overlay (matching the previous concept): thin gold band across the top showing a coin icon and a wheat-sheaf icon with numbers, and a horizontal "FARR" status bar filled approximately 65% in luminous golden-green. Minimap in the bottom-right corner showing a tiny version of the battlefield with red and blue unit dots. A row of four small ornate command buttons in the lower-right.

This is meant to look like a playable game screen, not a cinematic moment. Every unit must be clickable and readable. Aspect ratio 16:9.
```

### Midjourney variant (compressed)

```
Persian miniature style RTS gameplay screenshot, TOP-DOWN HIGH-ANGLE ISOMETRIC battlefield view from above (like Age of Empires II or StarCraft II camera), entire battlefield laid out below viewer, Iranian village with gold-domed Atashkadeh fire temple in lower-left seen from above, turquoise river, ranks of Pahlavan soldiers in formation with round Faravahar shields visible from above, hero Rostam on chestnut horse central in tiger-pelt cloak with slight golden glow, Turanian horseback raiders advancing from upper-right with red and black horse banners, thin band of distant snow-capped Alborz mountains across the top, 30 small units visible total, ornamental gold-indigo geometric border, flat colors, gold leaf highlights, fine ink linework, no shadows, jewel-tone palette, thin gold UI band at top with coin/grain icons and FARR meter, minimap in corner, ornate command buttons --ar 16:9 --style raw --v 7
```

### What to look for when you get the result

- **Camera angle**: did the model actually go top-down? If it produced another ground-level dramatic shot, the prompt didn't push hard enough — try adding "bird's-eye view" or "viewed from a bird flying overhead" as additional anchors.
- **Unit readability**: can you see ~30 distinct units, each with a clear silhouette? Or did it produce 5–8 units with character detail?
- **Style survival**: does the Persian-miniature aesthetic hold up at smaller unit sizes, or does it look generic when figures are tiny?
- **Hero scale**: Rostam should be slightly larger than other units but in proportion — not towering. If he dominates the frame, the prompt slipped back toward cinematic.

### Iteration notes (filled 2026-04-23 after generation)

**Result:** Excellent. Camera went properly top-down high-angle isometric on the first try. ~40 units visible with clear silhouettes. The Persian miniature style held up beautifully at gameplay scale — actually flattered by the format, because Persian miniatures' traditional tilted-ground perspective is essentially isometric. We're not fighting the style to get a playable view; the style is *already* shaped this way.

**What worked:**
- Camera angle (~45 degrees from vertical, like AoE2/SC2)
- Unit density and silhouette readability
- Hero scaling — Rostam slightly larger with golden glow, NOT towering
- Faction visual separation (blue Iran formation vs. red Turan cavalry advance)
- Village reads as a base (cluster of flat-roofed houses, gold-domed Atashkadeh with sacred flame, wheat field with worker figures)
- HUD integration — the four ornate command buttons in the lower-right corner (helmet/swords/horse/building) are particularly strong
- Painted minimap with red/blue dots looks like a real RTS minimap rendered in the style
- Style coherence: jewel-tone palette, gold leaf, fine ink linework, no shadows — all preserved

**What missed (minor, fixable in future prompts):**
- Iranian shields rendered as generic blue rather than Faravahar-marked
- Pahlavan armor reads more as generic medieval infantry than specifically lamellar scale
- Iran's banners (blue) are less iconographically distinct than Turan's (red with horse motif)

**Significance:** This validates the **two-tier visual approach** for the project. Cinematic/menu/marketing aesthetic = `gameplay_001` style (dramatic, ground-level, painterly). In-game aesthetic = `gameplay_002` style (high-angle, isometric, painted-tile). Both achievable from the same source style with prompt-level steering. Recommended for a `DECISIONS.md` entry.

**Saved as:** in-game visual direction reference. The art-production pipeline (whenever we get there — post-Tier-0) targets this look.

**Next visual tests worth running** (lower priority — not blocking anything):
- Single-unit close-up at 1x gameplay zoom (to see how unit detail reads at the smallest scale a player would ever encounter)
- Kaveh Event in progress — what does the screen look like during a Farr-collapse revolt? (Red flash? Ornamental border turning to thorns? Workers visibly walking off?)
- Empty terrain at gameplay angle (no units — to evaluate how much of the look comes from figures vs. ground)
- Atashkadeh build closeup (one building, fully detailed, what we'd target for a building sprite)

---

## Template for future prompts

When adding a new prompt to this file, use this structure:

```
## YYYY-MM-DD — short_name_in_snake_case

**Goal of this prompt:** what we're trying to learn or test.
**Best for:** which generator(s).

### Prompt
[the actual prompt]

### Variants
[for other generators if useful]

### What to look for
[evaluation criteria]

### Iteration notes
[after generating, what worked / what didn't, and what to try next]
```
