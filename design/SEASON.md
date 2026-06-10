# SEASON — the season track (reward content layer)

Locked 2026-06-09. Numbers locked 2026-06-10. Sourcing re-priced 2026-06-10 (see "Pricing reality").
XP source: `notes/task_system.md`. Point economy: `notes/season_pass.md`.
Cosmetic model + rules: `design/COSMETICS.md`. Board/obstacle model: `notes/board_obstacle_model.md`.

---

## What the track is

A **free, earned-only** cosmetic ladder. 30 tiers, milestones at **10 / 20 / 30**. One row, no
premium track, no pricing shown (the absence of a buy button says "free" — don't label it).

- **XP is earned from tasks, not from playing.** See `notes/task_system.md`.
- **The track carries common + rare only.** Prestige never appears on the track — Ranked
  placement rewards (Title + Frame + Rank Sticker) are Ranked-exclusive (`design/COSMETICS.md`).
- **Numbers locked:** 8wk / 30 tiers / 30,000 pts / 120-600-2,400 payout chain. See `notes/season_pass.md`.

---

## Pricing reality (re-priced 2026-06-10)

The GDS+ membership lapsed — **all GDS pricing is now full price, no FREE+, no supporter discount.**
It renews annually, so it is not worth $100+ to recover ~$5 of per-item savings. Every "FREE+" in
the old sourcing column was re-checked at full freight, and the season was re-sourced to lean on
**what's already owned** plus **runtime recolors**, not new purchases. Net effect: the track ships
at **$0**, and the only S1 spend is one board/obstacle pack.

---

## Reward types per tier (supply-driven)

Frequency follows supply (`design/COSMETICS.md` → supply-driven reward economy). Abundant,
renewable slots carry the volume; scarce slots are the milestones. **Boards reclassified
scarce → abundant** this session — the path is procedural and the ground is a swappable tiling
texture, so a board is "any seamless top-down ground that contrasts the path," not a rare matched
tileset (`notes/board_obstacle_model.md`).

- **Frequent commons** (most tiers): titles, zone recolors, mob recolors, FX variants, sticker
  shapes — all renewable at ~zero cost each season.
- **Uncommon** (spread between milestones): board biomes, frames, banners.
- **Milestones (10/20/30): tower skins** — the scarce hero asset. The **crystal trio is the three
  escalating milestone towers**: fire → ice → dark, across seasons 1–3.

---

## S1 tier map

Source column re-priced; "owned"/"$0 recolor" means no purchase needed.

| # | Type | Item | Source (re-priced) |
|---|---|---|---|
| 1 | Title | "Recruit" | free (text) |
| 2 | Mob | recolor (green) | **$0** — runtime tint of owned **undead** (Monster Maker dropped) |
| 3 | Zone | recolor: teal | $0 runtime tint |
| 4 | FX | projectile recolor: gold | $0 tint of owned default projectile |
| 5 | Frame | wood frame | $0 owned (Wood-UI kit) |
| 6 | Mob | animated fish | $0 owned — **perspective check** (side-profile risk) |
| 7 | Title | "Pathfinder" | free |
| 8 | Board | Forest biome | **$0** — recolor owned **Summer** to a denser green |
| 9 | FX | impact recolor: blue | $0 tint |
| **10** | **Tower** | **Fire crystal** + fireball FX | tower owned; **fireball FX $0.45** |
| 11 | Mob | recolor (purple) | $0 tint of owned undead |
| 12 | Zone | recolor: magenta | $0 |
| 13 | Title | "Maze Runner" | free |
| 14 | FX | fireball trail | bespoke (fireball FX pack) |
| 15 | Banner | Mint Choco panel | **$0** — author from owned Wood-UI (kit dropped; not worth $16.95) |
| 16 | Mob | starfish | $0 owned (reads top-down) |
| 17 | Board | Beach biome | $0 owned (Tiki beach) — **CC wire it** |
| 18 | FX | smoke ring impact | $0 owned FX bench (tower packs) |
| 19 | Title | "Overclocked" | free |
| **20** | **Tower** | **Ice crystal** + ice spell FX | tower owned; **ice FX $8.95** |
| 21 | Mob | recolor (cyan) | $0 tint of owned undead |
| 22 | Zone | recolor: amber | $0 |
| 23 | Frame | Parchment frame | **$0** — author from owned Wood-UI (kit dropped) |
| 24 | FX | lightning ball | $0 owned FX bench (tesla) |
| 25 | Title | "Gauntlet Veteran" | free |
| 26 | Board | **Suburbia** (was Toy-brick) | **$19.95** — Suburbia mega pack: board ground **+** its obstacle pool |
| 27 | Mob | hammerhead shark | $0 owned — **perspective check** |
| 28 | Sticker shape | speech-bubble outline | $0 owned |
| 29 | FX | explosion recolor | $0 owned FX bench |
| **30** | **Tower** | **Dark crystal** + dark FX | tower owned; FX = $0 recolor of owned bolt |

**S1 forced spend: $29.35** — Suburbia $19.95 + ice FX $8.95 + fireball FX $0.45. Everything else is
owned, authored, or a runtime recolor. **Bespoke milestone FX purchased:** the Fire (10) and Ice (20)
milestones + the fireball trail (14) use real FX art, not recolors; Dark (30) stays a recolor. Under
the $40 season cap with ~$11 headroom.

**Tier 26 retag:** `board_toybrick` → `board_suburbia` in `cosmetics_catalog.gd` ITEMS + TRACK.
Toy-brick is dead (rejected on taste). Suburbia does double duty for one buy: the T26 board ground
*and* that board's obstacle pool (houses, slides, fences — props nothing else owned provides).

**Note on tier 28:** the track grants the sticker *shape*. The populated rank sticker (auto-text +
tier tint) is still Ranked-exclusive per `design/COSMETICS.md` — no prestige leak.

---

## Ranked tier rename (affects prestige bundle)

Ranked tiers renamed **Stone → Bronze → Silver → Gold → Masters** (was Bronze/Silver/Gold/
Platinum/Masters). **Pure rename — ladder scale, LP thresholds, demotion buffer, MMR pacing, and
the resim are all unchanged.** The League-badges pack maps 1:1 by name (stone/bronze/silver/gold
art; the pack's diamond art = Masters; wood unused). The prestige Title/Frame bundle in
`cosmetics_catalog.gd` (`title_*`/`frame_*`) and the ladder docs (`pvp_ladder.md`,
`leaderboards.md`, `ghost_ladder.md`) need the name propagated — CC find/replace, logged in
`notes/open_items.md`.

---

## Sustainability

~8 authored tower skins total → one tower milestone per season (crystal trio covers S1–S3;
budget new tower-art purchases for S4+). Everything abundant renews free. Boards now renew free too
(recolor an owned ground, or a cheap themed pack when a season wants character — Suburbia is the S1
example, ~$20, amortized across the board *and* its obstacle library).
