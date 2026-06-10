# ASSET BUY LIST — post-audit (2026-06-10)

**Superseded the old curation pass.** The S1 asset list was audited section by section against the
hard constraints (top-down only; boards judged by the *real* engine model, not "has path tiles").
Most of the old list was ruled out. This file now records the **outcome**, not the aspiration.

**Pricing reality:** the GDS+ membership lapsed — **all prices full, no FREE+, no supporter rate.**
Renews annually; not worth $100+ to recover ~$5 of savings. Sourcing was redone to lean on owned
assets + runtime recolors.

---

## TOTAL S1 SPEND: $29.35

- **Top down suburbia mega pack — $19.95** — PURCHASED + DOWNLOADED. Does double duty: the **Tier 26
  board ground** (`board_suburbia`, replacing dead toy-brick) **and** that board's **obstacle pool**
  (houses, slides, fences — props nothing else owned provides). CC: slice ground + footprint-tag props.
- **2d ice effects pack — $8.95** — PURCHASED. Bespoke ice FX for the Ice Crystal milestone (T20).
- **Rotating fireball FX — $0.45** — PURCHASED. Bespoke fire FX for the Fire Crystal milestone (T10)
  + fireball trail (T14).

Everything else on the S1 track is **owned, authored, or a runtime recolor → $0.** See
`design/SEASON.md` for the tier-by-tier source column.

---

## Board audit outcome — the kill-criterion was wrong

The original board picks were terrain tilesets bought on the assumption a board needs matched
`grass|path|grass` tiles. **It doesn't.** The path is a procedural Line2D (`road_renderer.gd`) and
the ground is a swappable tiling texture (`map_loader.gd`) — independent layers. A board = any
seamless top-down ground that contrasts the gold/outlined path. Full reasoning:
`notes/board_obstacle_model.md`.

Consequence: boards reclassified **scarce → abundant**. S1 boards:
- **Summer** — owned, default.
- **Forest** (T8) — recolor owned Summer to denser green. $0.
- **Beach** (T17) — owned (Tiki beach), CC to wire.
- **Suburbia** (T26) — purchased (above). Was toy-brick (rejected on taste).

The owned **Level map path creator** line is shelf-ware for the path (CC only sampled its palette);
salvage value is its marker art (flags/stars/buttons) for entry/exit markers only.

---

## Mobs — audit outcome

Surviving packs after the top-down pass (each yields multiple skins; per-file counts need CC to read
the downloaded sprites — store gives no manifest):
- **Top down zombies mega pack** — OWNED (undead default; 1 skin live, more inside)
- **Four-directional elemental slimes**, **Slugoids**, **Tentacloid**, **Larvoid**, **Bugoid** —
  approved on taste (top-down). Buyable ~$5 each if/when a future season pulls them in; **not bought
  for S1** (S1 mobs are covered by owned + recolors).

S1 track mobs, all $0: undead recolors green/purple/cyan (runtime tint of owned undead — Monster
Maker kit **dropped**); **fish / starfish / hammerhead** all owned (perspective check pending —
plain side-profile fish is the risk).

Killed on perspective: one-eyed collection, cute slime, comic singles (fat/imp/blob/green), Monster
#2–7, Monster Maker kit.

---

## FX — audit outcome

Owned FX bench (from the tower packs) covers **smoke ring, tesla lightning, explosion** (tiers
18/24/29); dark (30) is a recolor. **Bespoke FX purchased** for the milestone hero tiers: ice
($8.95, T20) + rotating fireball ($0.45, T10 + trail T14). Projectile recolors gold/blue are tints.

Killed: Books of magic and spells (icons, not impact FX). Shield + Spiral survive as candidates but
are **Zone-slot** material, not projectile FX, and exceed the zone "recolor-only" spec — parked for
the Zone-slot discussion, not bought.

---

## Frames / banners / flair — audit outcome

- **Wood frame** (T5) — owned (Wood-UI kit).
- **Mint Choco banner** (T15) + **Parchment frame** (T23) — **authored from the owned Wood-UI kit**
  (single-hue outline art). The $16.95 GUI kits are **dropped** — full price makes extracting one
  piece each indefensible.
- **League badges** → Ranked **tier emblems** (system art, not a season reward). Tiers renamed
  Stone/Bronze/Silver/Gold/Masters; badge art maps 1:1 by name (diamond → Masters; wood unused).
- **Medals** — **cut** (no equip slot).
- **UI build kits** — not rewards; build material only.

---

## Owned — no action (tower / FX bench / boards / flair)
- **Towers (all skins):** arrow box (default), ballista, slingshot, tesla, magic eye, crystal ×3,
  catapult (needs PNG export by CC). Crystal trio = the S1–S3 milestone towers.
- **FX bench:** arrow, cannonball + explosion + smoke ring, tesla lightning, magic bolts + portals.
- **Board grounds:** summer (default) + autumn/winter/spring, beach, underwater, wild-west, post-apoc
  (verify in art folder).
- **Aquatic mobs:** fish (×several), starfish, hammerhead/shark, enemy fish pack.
- **Flair:** Wood-UI kit (frames/banners + screen-build material).
