# Board & obstacle model — how boards actually render

Synthesized 2026-06-10 from reading `src/scripts/road_renderer.gd`, `map_loader.gd`,
`cosmetics_catalog.gd`, `obstacle.gd`. This corrects a wrong mental model that made boards look
scarce and expensive. They are neither.

---

## The path is code, not tiles

`road_renderer.gd` draws the path as a **3-layer `Line2D` stack** through the path's cell-centres —
not placed tileset pieces:

- **outline** — `#2e2a14`, width `1.04 × cell` (drawn at back, widest → reads as a border)
- **fill** — `#c9a93f` gold, width `0.84 × cell`
- **highlight** — `#e2c45a`, width `0.58 × cell`

Rounded corners come free from `LINE_JOINT_ROUND`. The path **re-routes on every tower hover**, so a
static authored tileset can't represent it — that's *why* CC made it procedural. The three colours
are export vars (`road_color` / `outline_color` / `highlight_color`), so the **path is recolorable
per board** to keep contrast on any ground.

**Consequence:** the dedicated path/level-map tilesets we own (Level map path creator, etc.) are
**not on the board** — CC only eyedropped their palette. They're shelf-ware for the path; salvage
value is only their marker art (flags/stars/buttons) for entry/exit markers.

**Caveat (CC's documented scar):** putting a *tiled texture* on a Line2D **warps at corners** (the
chevrons "smeared into a blob"). So a flat-colour path is robust; a *textured* path fill is the one
thing that needs an experiment session. Flat path + textured ground covers almost everything.

## The ground is a swappable tiling texture

`map_loader._setup_background`: the board ground is a single texture (`summer_grass_tile.png`) on a
`TextureRect` set to `STRETCH_TILE` across the grid, with a darker edge rect behind and the grid
overlay on top. `collection.gd` loads the board cosmetic as `_tex_or(equipped board, summer)`.

**So a board skin = a swapped tiling texture. Boards never needed matched path tiles.** The old
audit kill-criterion "pack has no path tiles" was filtering on a requirement the engine doesn't
have. The real board filter is three things:

1. **Top-down** (still real)
2. **Tiles seamlessly** (it's a repeating fill — the base tile must loop with no seam)
3. **Contrasts the path** (gold fill + dark outline must stay legible; and the ground must not
   swallow towers/mobs/zone circle stacked on top — the one hard legibility filter)

Board variety mechanism = whole-set recolor of an owned ground (how Summer→autumn→winter→spring
work), or any cheap seamless top-down tile. This reclassifies boards **scarce → abundant**: they can
recur across the track instead of being hoarded for deep tiers.

---

## Obstacles are seeded SIM content, not decoration

`obstacle.gd`: a prop **occupies and blocks** its footprint cells — towers can't be placed there AND
the mob pathfinder treats it as a wall and routes around. Art is base-anchored and may overhang
*upward* (cosmetic), but the footprint is what blocks. **"Hand-placed in campaign; random in MP."**

Because obstacles block, they are **sim, not cosmetic** — they change the maze. In a ranked game
with a resim contract this has a hard edge:

- **The blocking layout (which cells, what footprint) must be one deterministic, shared,
  resim-fed seed.** Client-random placement = two players get different mazes on the "same" board
  (unfair) and the anti-cheat resim can't reproduce the board (broken). "Random in MP" already
  exists, so the hook is there — CC must confirm it's deterministic + resim-fed before the library
  grows.
- **Prop ART can vary freely over a *fixed* footprint** — a 1×1 blocked cell rendering as a rock vs
  log vs bush is pure cosmetic richness, costs the sim nothing. This is the safe "alive levels" win
  and fixes the current "same 3 assets over and over."
- **Varying the footprint** (1×1 vs 2×2) *is* gameplay and must ride the same seed.

**S1 plan:** build the obstacle library from the **Suburbia** pack, **scoped to the Suburbia board
only** (a slide on a beach board looks insane). Forest/Beach/Summer keep seeding from owned props;
a generic nature-prop buy is a *later, deliberate* purchase if the alive-levels payoff proves out in
playtest. Each prop gets a footprint tag; the seed picks art (and optionally footprint)
deterministically.
