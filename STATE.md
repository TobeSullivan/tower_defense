# State — Wend
Last updated: 2026-06-10

## Current focus
S1 cosmetic implementation (CC). Boards, ranked rename, apply-skins-in-match, and the
**Suburbia obstacle library** are **done**; what's left is FX behavior + frames/banners.

## ⏭ NEXT UP (start here next chat)
S1 implementation, remaining phases:
1. **Bespoke FX (②)** — **direction LOCKED this session** (`decisions.md` Cosmetics): FX is a set
   of HOOK points. *Body* hook = the projectile sprite IS the fireball/bolt (same path/speed/size
   as the arrow); *impact* hook = detonation/burst on hit (**noise-gated** — small/short, eyeball
   at scale via `match_shot`, dial back to on-kill-only if busy); *trail* hook. Fireball (T10/14) +
   ice (T20) frames extracted in `art/` (zips). **Build:** wire the hook system, map each catalog
   `fx_*` to its hook(s), then owned-bench FX (smoke ring/lightning/explosion) + dark recolor. SFX ok.
2. **Frames/banners (⑥)** — author from the owned Wood-UI kit (single-hue outline art).
- **Parked/flagged:** zone tint in-match (clashes with type-color legibility — design call);
  mob recolors (no-tint-painted-sprite rule conflict); aquatic-mob perspective check; Beach
  T17 **BLOCKED** on Tiki art upload. Full detail: `notes/open_items.md` "S1 cosmetic sourcing".

## Last session (2026-06-10, CC — S1 obstacles + FX direction)
- **Suburbia obstacle library (③) shipped.** Decoupled obstacle ART from the seed: the generator
  now bakes only the blocking footprint (empty `prop_id`); art is resolved LOCALLY per equipped
  board by `ObstacleProps.art_for(board, footprint, cell_key)`. `obstacle_props.gd` reorganised into
  per-board pools (default urban-decay + new SUBURBIA: 18×1×1 greenery/clutter, slide 1×2, pond 2×2);
  20 props extracted to `src/assets/environment/suburbia/`. `map_loader._setup_obstacles` threads the
  local `board_id` + resolves art; authored `.tres` prop_id still wins. sim_harness all-5 green
  (dmg shifted 54985→67903 as the seed-777 layout changed; live==resim holds), cosmetics green, and
  the Suburbia board renders bushes/chairs (was grey rubble) in a real M1 shot. **Render-unverified:**
  slide (1×2) + pond (2×2) only spawn on generated maps — footprints exercised by sim_harness, not yet seen.
- **FX direction LOCKED** (see NEXT UP ② + `decisions.md`): hook-based (body/impact/trail), impact noise-gated.

## Prior session (2026-06-10, CC — S1 implementation)
Three phases shipped (commits `03b9aae` → `5c563b0`, pushed):
- **Boards:** Suburbia red-brick (T26, retag from toy-brick) + Forest baked pine recolor (T8);
  obstacle determinism gate **verified cleared** (whole map incl. obstacles derives from one
  shared host seed; resim rebuilds from `record[seed]`). Beach still blocked.
- **Ranked rename:** Stone/Bronze/Silver/Gold/Masters — pure positional relabel, ladder math
  unchanged; all 4 ranked test suites + 5 docs updated; promoted to `decisions.md`.
- **Apply skins in match (⑤ complete for art-in-hand):** board biome + tower body + projectile
  tint, **local board only** (opponents default; nothing routes through the match record).
  Shared resolver `CosmeticsCatalog.texture_for/tint_for`. Verified in real M1 matches via the
  reusable `match_shot.tscn` harness; sim_harness round-trip + determinism green.

## Earlier session (2026-06-10, design)
Audited the full S1 asset list section by section against top-down + the *real* board model:
- **Board architecture corrected:** the path is a procedural Line2D (`road_renderer.gd`); the ground
  is a swappable tiling texture (`map_loader.gd`). Boards need **no matched path tiles** — any
  seamless top-down ground that contrasts the path works. Boards reclassified scarce → abundant.
  Captured in `notes/board_obstacle_model.md` (NEW).
- **Obstacles reclassified:** they **block** (sim, not cosmetic), "random in MP." Design rule:
  positions + footprints on one deterministic resim-fed seed; art free over a fixed footprint.
- **Suburbia mega pack purchased ($19.95):** Tier 26 board ground (replaces dead toy-brick) **+** its
  obstacle pool. Retag `board_toybrick` → `board_suburbia`.
- **Membership lapsed → all GDS full price.** Re-sourced the track to owned + recolors → the track
  itself ships at **$0**; only Suburbia + two bespoke milestone FX (ice/fireball) are bought.
- **Ranked tiers renamed** Stone/Bronze/Silver/Gold/Masters (pure rename, ladder math unchanged);
  League badges → tier emblems; medals cut; UI kits → build material (frames/banners authored from
  owned Wood-UI).
- Aquatic mobs (fish/starfish/hammerhead, T6/16/27) confirmed **owned**; perspective check pending.

## Other open threads (not the immediate next step — see NEXT UP above)
- **Steam (blocked on verification):** clears → create Wend App ID → create Playtest app
  (confidential/friends-only; hidden page, manual keys). Confirm entity type at registration.
- **Design (own session):** finalize season-pass absolute threshold integers once playtest data
  exists (`notes/season_pass.md`).

## Recently touched files (this CC session)
- `src/scripts/cosmetics_catalog.gd` — `board_suburbia`/`board_forest` art; prestige rename (Stone↔Platinum); `texture_for`/`tint_for` resolvers
- `src/scripts/map_loader.gd` — equipped board/tower/proj applied for `is_local`; `collection.gd` — DRY resolver
- `src/scripts/{tower,build_controller,projectile}.gd` — tower body skin + projectile tint plumbing
- `src/scripts/leaderboard_service.gd` / `leaderboard_browse.gd` — ranked band rename
- `src/assets/maps/{suburbia,forest}_tile.png` (NEW) · `src/tools/match_shot.*` (NEW reusable in-match shot harness)
- tests updated green: `leaderboard` · `ranked_lp` · `nakama_backend` · `cosmetics` · `sim_harness`
- docs: `notes/{open_items,decisions,pvp_ladder,leaderboard_schema,leaderboard_ui_spec,multiplayer_architecture}.md`, `design/DESIGN_MODES.md`

## Open questions / blocked on
- **Steam:** identity verification pending (2–7 biz days from 2026-06-07). Confirm entity type.
- **Aquatic-mob perspective** — fish/starfish/hammerhead read on a top-down board? CC render check.
- **Absolute task thresholds** (the X integers) — playtest-gated.
- Full open backlog in `notes/open_items.md`.
