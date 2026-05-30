---
id: farr
type: concept
title: Farr
title_fa: فرّ
aka:
  - farreh
  - farr-e izadi
  - farr-e kiani
  - khvarenah
  - khwarrah
  - khorra
  - فرّه
register: myth
summary: >-
  The divine radiant glory that legitimizes a just ruler and abandons the unjust
  — political theology made visible.
relationships:
  departs_from:
    - jamshid
primary_text:
  - fa: چو این گفته شد فرّ یزدان از اوی / بگشت و جهان شد پر از گفت‌وگوی
    translit: >-
      cho in gofte shod farr-e yazdān az uy / be-gasht o jahān shod por az
      goft-o-guy
    en: >-
      When this was said, God's glory departed from him — and the world filled
      with murmur.
    source:
      ref: ganjoor
      loc: 'Jamshid §1, beyt 70'
      url: 'https://ganjoor.net/ferdousi/shahname/jamshid/sh1'
game:
  maps_to:
    - mechanic-farr
  anchor_category: null
sources:
  - iranica
  - ganjoor
  - khaleghi-motlagh
related:
  - rostam
  - jamshid
status: draft
tags:
  - concept
  - theology
  - legitimacy
  - kingship
---

## Story

The *farr* (فرّ) is the luminous divine glory that marks the legitimate. It settles on a just king and makes his rule cohere; when he turns to pride or the Lie (*druj*), it departs, and his realm collapses. Its archetypal loss is [[jamshid]]'s: the great civilizer-king, grown arrogant enough to claim divinity, watches his *farr* leave him — and tyranny (Zahhak) rushes into the vacuum. The concept appears in two load-bearing forms: **farr-e izadi** (فرّ ایزدی), the god-given glory, and **farr-e kiani** (فرّ کیانی), the specifically royal/Kayanian glory. It is not a personal virtue but a *force* — present, visible, and losable.

## History

The *farr* descends from the Avestan **xᵛarənah-** (*khvarenah*), "radiant glory," from the root *\*hvar* "to shine" (Yasht 19, the *kavaēm xᵛarənah*, the Fortune of the Kayanian kings). Old Persian/Median *farnah-* → Middle Persian *xwarrah* → New Persian *farr / farreh* (and the doublet *khorra*). This is documented etymology (Gnoli, *Encyclopaedia Iranica*, "FARR(AH)"), distinct from Ferdowsi's narrative use of the word.

## Primary text

The canonical *farr*-departure couplet — Jamshid §1, beyt 70 — sits in this entry's primary_text frontmatter, fetched verbatim by the code session. It is the moment [[jamshid]] declares himself sovereign and, at that word, the glory leaves him.

The brevity is the point: there is no battle here. The transgression is a *sentence* — Jamshid declares himself the maker of all good — and the *farr* simply turns away. See [[jamshid]] for the full pride-fall arc; for the corresponding *farr*-**restoration** moment, see [[rostam]]'s entry, where the Simorgh returns the same force to the wounded hero. Together they bound the concept: it can leave, and it can return — but never by the act of the one who holds it.

(Per the verse-handoff protocol: the Persian text lives only in primary_text frontmatter and is assembled from Ganjoor by the code session; no Persian verse typed from memory.)

## Game lens

Farr is the heartbeat mechanic of the project — the **Farr-e Izadi** meter. Hero standing rises with just action and drains with injustice; loss degrades morale, production, and abilities. It is the Shahnameh's explicit political philosophy made playable, and it touches every hero, above all [[rostam]] and (in archetype) [[jamshid]]. Maps to `mechanic-farr`. (Per project convention, all *farr* changes flow through a single logged function.)
