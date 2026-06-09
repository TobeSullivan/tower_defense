# COSMETICS — cosmetics & collection meta-layer

Locked 2026-06-09. The content model + IA the Collection and Season surfaces hang off.
Screens mocked in `notes/mockups/collection_mock.html` + `season_mock.html` (real owned art,
real authored `mission_01` maze cropped to the maze window as the live loadout preview).

**Why this is viable solo:** every asset on gamedeveloperstudio.com is one artist, one coherent
style. Coherent art is normally the thing that kills a cosmetics layer; here the whole catalog can be
bought at ~$2–15/pack and is guaranteed to sit together. The single-tower / single-mob pillar becomes
the *reason* cosmetics work — a deliberately spare game earns visual richness through paint, not mechanics.

---

## 3 cardinal rules (these protect the pillars — do not bend)

1. **Cosmetics are 100% visual. Zero gameplay / zero competitive effect.** Tower footprints stay
   square, hitboxes / ranges / timings unchanged. This is what lets a Ranked game ship skins at all.
2. **Skins never enter the sim.** Equipped cosmetics are a client render-layer setting — never in the
   input log, never re-simmed. (CC: do not route equipped-skin state through the match record, or it
   breaks determinism / authoritative re-sim.)
3. **Cosmetic FX match the default's silhouette + duration — only the paint changes.** A reskinned
   projectile/impact can't be louder or longer than stock. Keeps the board calm (JUICE guardrail) and
   Ranked readable.

---

## The color decision (FINAL — forced by the owned art)

The owned pack ships **7 distinct tower sprites** (arrow box, ballista, slingshot, cannon, tesla,
magic-eye, catapult). Distinct sprites cannot coexist with a "pale → vivid → near-black" tower-body
upgrade ramp — a skinned tower has its own colors. So:

- **Tower growth / investment signal moves OFF the body** → a **base aura ring + size step** (and the
  existing multishot + fire-rate + tower info box already carry legibility). The mock shows the aura
  growing across L1→L3 while the body stays the equipped skin.
- **The tower body is a pure skin slot.**
- **Zone color is NOT load-bearing as long as the labels stay** (already locked) → zone recolors are a
  valid cosmetic.

---

## The 8 equip slots

**In-match** (change the match view):
- **Tower** — body sprite. 7 owned.
- **Board biome** — surface + grass + path tiles as one themed set. 5 seasons owned + beach/underwater/wild-west/post-apoc owned.
- **Zone** — bonus-zone treatment (labels always stay).
- **Projectile + FX** — the shot and its impact, paired as one set.
- **Mob** — the horde's look. One type mechanically, many paints.

**Profile flair** (your identity card in lobby / leaderboard / result screens — where skins actually get *seen*, since Ranked is mostly your-own-board):
- **Frame** — border around the avatar.
- **Banner** — background behind your name.
- **Title** — text tag under your name (chosen from an earned list, never free text).

**Identity is from Steam, read-only:** display **name + avatar** come from the Steam persona and are
never editable in Wend. **Zero UGC anywhere** (no name editor, no image upload, titles are pick-from-list)
→ Wend is never in the name/image-moderation business; Valve's moderation is inherited for free. This
is structural, not a profanity filter (filters hit the Scunthorpe problem and miss deliberate bad actors
anyway).

---

## Source × rarity (rarity = how hard it was to get, never luck — no gacha)

- **Common** — campaign completion, first-time milestones, season-track tiers.
- **Rare** — Trials leaderboard placement, deep season tiers, achievement chains.
- **Prestige** — Ranked tier + seasonal ladder placement. **Never buyable, ever.**
- **Paid** — optional themed DLC packs, one-time. **Disjoint from earnable + prestige** (paid never
  overlaps what you can earn — locked posture).

---

## Season

- **Earned-only ladder, no prices shown.** ~30 tiers, points from all modes (`season_pass.md` soft
  example: 8wk / 30 tiers / 1000 pts). Single row — no premium track (honors $10–15 no-MTX). **Do not
  label it "free"** — the absence of any buy button says it.
- Milestones at **10 / 20 / 30** carry the headline rewards (a tower / board / prestige item).
- States: claimed · claimable · current (you-are-here + progress to next) · locked.
- **Rewards pull from this same catalog** and cross-link into Collection to equip.

---

## IA — two homes, not three tabs

The earlier 3-tab strip (Locker / Codex / Season) was wrong: it implied co-equal toggle-views.

- **Collection** = Locker + Codex merged. One screen, two lenses on the *same catalog*: the **loadout
  lens** (preview-forward, equip what you own) and the **collection lens** (grid-forward, completion %,
  locked silhouettes, buy). Per-slot completion on each slot chip; overall completion top-right. Reached
  deliberately from home.
- **Season** = its own system, surfaced everywhere — **home widget** (tier + next-reward peek), **post-match
  nudges** on Trials/Ranked result screens (+pts → tier progress → unlocked), and the **full track screen**.
  Not a peer tab; reached from home + match-flow. Cross-links: a just-unlocked reward → Collection to equip;
  a Collection item tagged "Season N" → the track.

Most Season surfacing is **modifications to surfaces that already exist** (home widget, match-end Surface
1/2, the promotion set-piece). The only net-new screens were Collection and the Season track.

---

## Codex / sticker-book behavior (now the collection lens of Collection)

- Owned → full real art + rarity tag, equippable.
- Earnable-but-unowned → **black silhouette** + how-to-earn hint ("Reach Gold III").
- Paid-but-unowned → **dimmed real art** + buy affordance ("Buy · <pack>"). The treatment difference keeps
  "paid never overlaps earnable" legible at a glance; the codex doubles as the storefront seam.

---

## Asset manifest (cosmetic → real source → repo target)

The game currently ships ONE of each (the defaults). Everything else is in the owned library and gets
imported into `src/assets/<kind>/` by CC as it's promoted into the catalog. Source paths are within the
owned pack (`art.zip` layout) unless marked in-repo.

| Slot | Catalog item | Status | Source |
|---|---|---|---|
| Tower | Arrow Box (default) | in-repo | `src/assets/towers/arrow_box_*` |
| Tower | Ballista | owned | `towers/ballista/PNG/ballista_loaded_front.png` |
| Tower | Slingshot | owned | `towers/sling_shot/PNGS/slingshot_front_view.png` |
| Tower | Cannon | owned | `towers/upright_cannons/PNGS/upright_cannon_01.png` |
| Tower | Tesla | owned | `towers/tesla_tower/PNGS/tesla_tower_01.png` |
| Tower | Magic Eye | owned | `towers/magic_weapons/PNGS/magic_eye.png` |
| Tower | Catapult | **owned, export needed** | `towers/catapult/` ships **SVG only** — export a PNG body |
| Board | Summer (default) | in-repo | `src/assets/maps/summer_grass_*` |
| Board | Autumn / Winter / Spring | owned | `PNGS/GRASS/*` + `PNGS/SINGLE_TILES/<season>/` (path autotiles) |
| Board | River | owned | `PNGS/SINGLE_TILES/RIVER/` |
| Board | Wasteland | owned | `environment_art/asphalt_tiles/` + post-apoc props |
| Mob | Undead (default) | in-repo | `src/assets/mobs/__zombie_01_*` |
| Mob | Fish / Slime / Starfish / Ghoul | **owned, import needed** | Enemy fish pack / Monster maker / Seaside — not yet in `src/assets/mobs/` |
| Projectile | Arrow (default) | in-repo | `src/assets/towers/arrow.png` |
| Projectile | Stone / Spark / Frost | owned | catapult ammo / tesla effect frames / winter effects |
| Zone | recolor treatments | derived | not discrete sprites — colored circle + retained label |
| Frame / Banner / Title | flair | derived | UI treatments (wood-UI kit borders / panels) + fixed strings |

UI to build the screens out of is already owned: the wood-UI kit (panels, shop awning, planks, icons,
meters) — the locker/codex/pass screens can ship with **zero new purchases**; buying is purely catalog depth.

---

## Deferred (structure locked, contents later)

- **Actual tier-by-tier season rewards** — which cosmetic sits on each of the ~30 tiers.
- **Full catalog contents** — the real per-slot item list (the mocks use a representative subset).
- **CC import tasks:** export a catapult PNG body; import alt mobs (fish/slime/starfish) and alt biomes
  (beach/bog) into `src/assets/` as they're promoted into the catalog.
- **Sprite-size tuning** in the loadout preview is a Godot-side render detail, not a design question.
