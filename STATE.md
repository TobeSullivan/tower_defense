# State — Wend
Last updated: 2026-06-10

## Current focus
S1 cosmetic implementation (CC): boards, ranked rename, apply-skins-in-match, Suburbia obstacles,
full FX track (8, real art), frames/banners (wood 9-patch tinted), the **Season Tasks panel**
(XP-earn surface), and the **post-match season nudge** all implemented. Remaining: judgment/tuning
passes (FX facings/sizes, frames/banners proportions) + Beach (needs a top-down sand tile).

## ⏭ NEXT UP (start here next chat)
S1 implementation, remaining phases:
1. **FX (②) — ALL 8 wired with real art** (`projectile_fx.gd`). Bodies: fireball (T10), arcane-bolt
   (T14), ice (T20), lightning (T24), dark (T30, recoloured orb). Impacts (on-kill, subtle):
   blue-impact (T9), smoke-ring (T18), explosion (T29). gold-bolt (T4) = tinted arrow by design.
   Art from the fireball/ice packs + **towers.zip** (cannon explode + smoke-ring sheet, tesla
   electric, magic projectiles). Hooks: body / impact (animated OR single-frame burst) / trail
   (built, currently unused). FX **Collection icons self-illustrate** now (`_item_art` pulls a frame
   from `ProjectileFX.icon_frame`). **Remaining FX work is judgment-only — a single playtest tuning
   pass:** sizes/alpha/facing per FX (arcane-bolt & lightning `face_offset` are guesses; lightning/
   dark recolor look; smoke-ring/explosion burst size). Not a per-item loop — review all at once.
2. **Frames/banners (⑥) — first pass shipped.** Wood-UI kit as `StyleBoxTexture` 9-patch, recoloured
   per item (one frame shape `frame_panel.png` behind the avatar, one banner shape `banner_plank.png`
   as the card bg; `_wood_box` in `collection.gd`). All catalog frame/banner tints drive it incl.
   prestige (tinted wood, not true metal — flag if that's not acceptable). **Tuning open:** avatar
   frame reads small + the banner plank is a large empty expanse (card is wide); prestige metal look;
   maybe a `panel_headboards` arched banner instead of a plank. Verify via `collection_shot.tscn`.
- **Parked/flagged:** zone tint in-match (clashes with type-color legibility — design call);
  mob recolors (no-tint-painted-sprite rule conflict); aquatic-mob perspective check. **Beach T17
  STILL BLOCKED:** the uploaded `Tikibeachshopgameassetpack` is **side-view shop art** (walls/shelves/
  horizon backdrop), NOT a top-down tileable sand ground — unusable for the board (verified the bg +
  sand_piece). Beach needs a real top-down seamless sand tile. Full detail: `notes/open_items.md`.

## Last session (2026-06-10, CC — S1 obstacles + FX fireball/ice)
- **Suburbia obstacle library (③) shipped.** Decoupled obstacle ART from the seed: the generator
  now bakes only the blocking footprint (empty `prop_id`); art is resolved LOCALLY per equipped
  board by `ObstacleProps.art_for(board, footprint, cell_key)`. `obstacle_props.gd` reorganised into
  per-board pools (default urban-decay + new SUBURBIA: 18×1×1 greenery/clutter, slide 1×2, pond 2×2);
  20 props extracted to `src/assets/environment/suburbia/`. `map_loader._setup_obstacles` threads the
  local `board_id` + resolves art; authored `.tres` prop_id still wins. sim_harness all-5 green
  (dmg shifted 54985→67903 as the seed-777 layout changed; live==resim holds), cosmetics green, and
  the Suburbia board renders bushes/chairs (was grey rubble) in a real M1 shot. **Render-unverified:**
  slide (1×2) + pond (2×2) only spawn on generated maps — footprints exercised by sim_harness, not yet seen.
- **FX hook system + flagship fireball (②) shipped.** `projectile_fx.gd` resolves the equipped "proj"
  id to body/impact hooks (LOCAL board only, render-only — opponents/resim get the plain arrow, so
  determinism is untouched). `fx_fireball` = animated fireball body (replaces the arrow, sized to its
  ~28px footprint, same speed) + a short impact burst on hit; crits keep the gold arrow tell (no FX).
  Threaded `fx_id` map_loader→build_controller→tower→projectile alongside `proj_tint`. 6 fireball
  frames in `src/assets/fx/fireball/`. **Ice (`fx_ice_spell`) wired too**: directional shard body
  (faces travel via per-art `face_offset`) + subtle on-kill shatter; frames in `src/assets/fx/ice/`.
  Impact tuned to **on-kill-only + small + translucent** after playtest (per-hit bursts occluded the
  mob). Skinned tower bodies no longer aim-rotate (crystals are radial). Dev: **F10** (global,
  debug-only) unlocks all cosmetics for testing. Verified: `fx_smoke` + sim_harness (67903) +
  cosmetics green. Other `fx_*` still tint-only arrows.

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
