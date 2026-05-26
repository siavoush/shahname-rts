# Codex — Authoring Conventions

*The single spelling, transliteration, sourcing, and citation standard for every codex entry. Derived from `00_SHAHNAMEH_RESEARCH.md §7` (binding canon) and a cultural-alignment review by the project's `shahnameh-loremaster`, with Persian orthography verified against Dehkhoda and Encyclopaedia Iranica.*

**Date:** 2026-05-24 · **Companion to:** `ARCHITECTURE.md`

---

## 1. Transliteration policy (decidable rules)

1. **Display names carry no diacritics.** `title` and body prose use clean Latin: "Rostam," "Esfandiyar," "Goshtasp" — never macrons or under-dots. The Perso-Arabic `title_fa` field carries the precise orthography; an optional `translit_scholarly` field may hold a marked academic form if ever needed.
2. **Apostrophe = ayn/hamza only**, and always a straight `'`. Use it where a real ع/ء sits between vowels and dropping it misleads pronunciation: **Mazra'eh** (مزرعه). Never decorative; never a curly `'`.
3. **Hyphenate the ezāfe and bound particles**, capitalize the head: **Farr-e Izadi**, **Derafsh-e Kaviani**, **Div-e Sepid**. Two full words stay spaced: **Haft Khan**. Compound throne-names stay open, both capitalized: **Kay Khosrow**, **Kay Kavus**, **Kay Kobad**.
4. **`-eh` for final he** (Atashkadeh, Rudabeh); **`-iyab`/`-iyar`** as the game uses (Afrasiyab, Esfandiyar).
5. **`title_fa` is fully vocalized where it disambiguates** (the shadda on فرّ is load-bearing). **`aka`** carries every variant a searcher might type (Rustam, Suhrab, Feraydun…), feeding search + redirects.
6. **Game-canon spelling wins on any conflict** with scholarly forms, but the scholarly form is recorded in `aka` so search still resolves it. Divergences are logged in §7 below.

---

## 2. The Farr correction (canonical — do not inherit the error)

`00_SHAHNAMEH_RESEARCH.md §5` renders the divine glory in Persian as **خرمن کیانی**. **This is an error** — خرمن (*kharman*) means "harvest / threshing-floor" and has no etymological relation to the glory concept. Verified against Dehkhoda + Encyclopaedia Iranica (Gnoli, "FARR(AH)"):

| Concept | Perso-Arabic | Romanization | Notes |
|---|---|---|---|
| the divine glory itself | **فرّ** (var. **فرّه**) | *farr* / *farreh* | MP *xwarrah*; Av. *xᵛarənah-* |
| divine (god-given) glory | **فرّ ایزدی** | *farr-e izadi* | *izadi* < Av. *yazata*; the form Jamshid loses |
| Kayanian / royal glory | **فرّ کیانی** | *farr-e kiani* | Av. *kavaēm xᵛarənah*, Yasht 19 |

One-line etymology for the `farr` entry: *Avestan* **xᵛarənah-** *"radiant glory" (root \*hvar "to shine") → Old Persian/Median* **farnah-** *→ Middle Persian* **xwarrah** *→ New Persian* **farr** *— a luminous divine charisma that legitimizes a just ruler and abandons him when he turns to the Lie (*druj*).*

`farr.md` carries a one-line provenance note recording this correction so the lineage is honest.

---

## 3. Starter name reference table

Confidence: ✔ = Persian spelling confident · ⚠ = double-check before locking. (From the loremaster review; game-canon display forms.)

| English display | Perso-Arabic | Variants → `aka` | Age | Conf. |
|---|---|---|---|---|
| Ferdowsi | فردوسی | Firdausi, Firdawsi | meta | ✔ |
| Shahnameh | شاهنامه | Shahnama, Shah-nameh | meta | ✔ |
| Keyumars | کیومرث | Kayumars, Gayomard | pishdadian | ✔ |
| Hushang | هوشنگ | Hooshang | pishdadian | ✔ |
| Tahmuras | طهمورث | Tahmures, Tahmurath | pishdadian | ✔ |
| Jamshid | جمشید | Jam, Yima (Av.) | pishdadian | ✔ |
| Zahhak | ضحّاک | Zahak, Zohak, Azhi Dahaka (Av.) | pishdadian | ✔ |
| Kaveh | کاوه | Kaveh Ahangar | pishdadian | ✔ |
| Fereydun | فریدون | Faridun, Thraetaona (Av.) | pishdadian | ✔ |
| Iraj | ایرج | Eraj | pishdadian | ✔ |
| Tur | تور | Tūr | pishdadian | ⚠ |
| Salm | سلم | — | pishdadian | ✔ |
| Manuchehr | منوچهر | Minuchihr | pishdadian | ✔ |
| Zal | زال | Zaal, Dastan | kayanian | ✔ |
| Rostam | رستم | Rustam, Rustem, Tahamtan (epithet) | kayanian | ✔ |
| Sohrab | سهراب | Suhrab | kayanian | ✔ |
| Rakhsh | رخش | Raksh | kayanian | ✔ |
| Esfandiyar | اسفندیار | Isfandiyar, Spandyad (MP) | kayanian | ✔ |
| Siavash | سیاوش | Siyavash, Siavush, **Siavoush** | kayanian | ✔ |
| Kay Khosrow | کیخسرو | Kai Khusrau | kayanian | ✔ |
| Kay Kavus | کیکاووس | Kai Kaus | kayanian | ✔ |
| Afrasiyab | افراسیاب | Afrasiab, Frangrasyan (Av.) | kayanian | ✔ |
| Piran Viseh | پیران ویسه | Piran-e Visa, Piran | kayanian | ⚠ |
| Aghrirat | آغریرث | Aghriras, Agrirath | kayanian | ⚠ |
| Forud | فرود | — | kayanian | ✔ |
| Farangis | فرنگیس | Farangees | kayanian | ✔ |
| Simorgh | سیمرغ | Simurgh, Saēna (Av.) | kayanian | ✔ |
| Div-e Sepid | دیو سپید | White Div, Div-e Safid | kayanian | ✔ |
| Iran | ایران | Ērān (MP) | concept/place | ✔ |
| Turan | توران | Tūrān | concept/place | ✔ |
| Mazandaran | مازندران | Mazanderan | place | ✔ |
| Mount Damavand | دماوند | Damāvand, Demavend | place | ✔ |
| Derafsh-e Kaviani | درفش کاویانی | Kaviani banner | artifact | ✔ |
| Sekandar | سکندر / اسکندر | Eskandar, Iskandar (Alexander) | sasanian | ✔ |
| Ardashir Babakan | اردشیر بابکان | Artaxšīr | sasanian | ✔ |
| Anushirvan | انوشیروان | Nushirvan, Khosrow I | sasanian | ✔ |
| Bahram Gur | بهرام گور | Bahram V | sasanian | ✔ |
| Yazdegerd | یزدگرد | Yazdgerd, Yazdegerd III | sasanian | ✔ |

---

## 4. False-friend concept glosses

Lead with the corrective literal, then name the false friend. Use in the concept entries and the in-game tooltips alike.

- **shah** (شاه) — a king whose legitimacy *is* the farr — divine glory, not bloodline or conquest alone. Not the European medieval "king": his authority is a moral-cosmic license that can be withdrawn.
- **pahlavan** (پهلوان) — a heroic champion of superhuman stature and a personal honor-code, bound to the throne yet greater than any single reign. Not a "knight": no feudal oath, no chivalric order.
- **div** (دیو) — an Iranian mythological category: a *daēva*, an anti-divine being aligned with Ahriman against cosmic order (*asha*). Not an Abrahamic "demon" (no fallen-angel theology); divs are a parallel creation — embodied, territorial, sometimes wise (Tahmuras learns writing from bound divs).
- **farr** (فرّ) — divine radiant glory that legitimizes the just and abandons the unjust — a force, present and losable. Not mere "glory"/"charisma": political theology made visible.
- **sepah** (سپاه) — the royal host as an institution that embodies the realm, raised under the shah. Not just "army"; the *sepahbod* commands it as an office of state.
- **dehqan** (دهقان) — a landed cultivator and keeper of old Iranian tradition (Ferdowsi's own class). Not a feudal "lord of the manor."
- **mobad** (موبد) — a Zoroastrian priest and keeper of the sacred fire and counsel. Not a generic "wizard" or "cleric."
- **azhdaha** (اژدها) — a venom-breathing serpent-dragon of Iranian myth (cf. Azhi Dahaka). Not the hoard-guarding Western "dragon"; closer to a chaos-serpent.
- **Ahriman** (اهریمن) — the hostile spirit, principal of *druj* (the Lie). Not "Satan": a co-eternal cosmic antagonist in a dualist frame, not a subordinate rebel.

---

## 5. Sources & how primary text is sourced

`content/sources.yaml` registers these reference ids:

| id | What | Use |
|---|---|---|
| `ganjoor` | **Ganjoor** (ganjoor.net) — complete Persian text, verse-by-verse | **Primary-text fetch source.** Every Farsi verse is fetched, never recalled from memory. |
| `warner-warner` | Warner & Warner (1905), complete English | Public-domain English; literal cross-check. |
| `davis` | Dick Davis (Penguin) | Best modern literary English. |
| `khaleghi-motlagh` | Khaleghi-Motlagh critical edition | Scholarly gold standard for the Persian. |
| `iranica` | *Encyclopaedia Iranica* | Per-character / per-concept reference + origin scholarship. |

**Verbatim fetch is confirmed working.** A live fetch of `ganjoor.net/ferdousi/shahname/aghaz/sh1` returned the clean opening, e.g.:

> به نام خداوند جان و خرد / کز این برتر اندیشه بر نگذرد

The Ganjoor page also exposes per-beyt numbering and a plain-prose paraphrase (*برگردان به زبان ساده*), and Ganjoor offers a JSON API (`api.ganjoor.net`) that should give cleaner programmatic access than scraping HTML — **to confirm when we build the fetch tooling.** Each `primary_text` entry stores `{fa, translit, en, source: {ref: ganjoor, loc/url}}` so every verse is traceable to its exact Ganjoor location.

---

### 5.1 Licensing, variants, caching, media (decided 2026-05-24)

- **Licensing — because the codex ships in-game.** Default to public-domain / our own material in anything shipped: the Persian (Ferdowsi) is public domain via Ganjoor; **Warner & Warner** (1905) English is public domain; many manuscript miniatures (Met open-access, old MSS) are public domain. **Dick Davis** is copyrighted — reference shelf and short quotes only, never wholesale reproduction in shipped content.
- **Variant readings.** The text differs across manuscripts (readers visibly dispute single words in Ganjoor's own comment threads). Adopt the **Khaleghi-Motlagh** reading as canonical; record significant variants in a note rather than implying one settled line.
- **Verses are cached, not live-fetched.** Ganjoor is an *author-time* source: once a verse is fetched it is committed into the entry's `primary_text` frontmatter. Neither the web build nor the game ever depends on Ganjoor being reachable at runtime. (The live page even carried a server-trouble banner — this is non-negotiable.)
- **Media.** Entries may carry `media: { images: [...], audio: [...] }` — manuscript miniatures and Ganjoor recitations. Each item records its own `source` + `license`; only public-domain / open-access media ships in-game.

## 6. The "text says X" vs "scholars hypothesize Y" wall

The per-entry **History** section draws on origin scholarship (Avestan roots, Saka/Scythian strata, comparative myth, historicization debates). **Discipline:** never present a scholarly reconstruction as if it were Ferdowsi's text. Canon statements ("Ferdowsi says…") and hypotheses ("Yarshater argues Rostam derives from a Saka hero…") are visibly separated and the hypothesis is attributed to its source. This mirrors the timeline's visible myth/history seam.

---

## 7. Open naming decisions (need Siavoush's call)

Game-canon wins by default, but these are judgment calls the loremaster flagged:

- **Siavash vs Siavoush** — scholarly is *Siyāvaš*; your own name is **Siavoush**. Which is the entry `title`? (the other → `aka`.)
- **Simorgh vs Simurgh** — `00_SHAHNAMEH_RESEARCH.md` uses "Simurgh"; "Simorgh" is closer to سیمرغ. Pick the `id`.
- **Haft Khan vs Haft Khwan** — research doc uses "Khwan"; simplest `id` is `haft-khan`.
- **Sekandar (Alexander)** — straddles legend/history; a deliberate `register` call when authored.
