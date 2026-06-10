# Open items — backlog ledger

**Delete-on-done.** This file holds only OPEN work. When something resolves, delete it; if it
encodes a must-not-reverse call, promote that one line to `notes/decisions.md` first. The history
of resolved items lives in `STATE_ARCHIVE.md`. STATE.md's "Open questions" points here.

Status key: **OPEN** · **BLOCKED-DATA** · **PARKED** (additive, not now) · **OWN-SESSION** (large)

---

## Steam (ops) — blocked on verification
- **Identity verification pending** (2–7 biz days from 2026-06-07, third-party Lilaham/TaxIdentity). Blocks finishing account creation + creating the App ID/Playtest. $100 Direct fee paid → 30-day release clock running (earliest ~2026-07-07).
- **Confirm the entity type** chosen at registration (individual vs company — matters for tax/bank + later restructure).
- **When it clears:** create the Wend App ID → create the Playtest app **confidential/friends-only** (Playtest App ID + Standard Release keys + Playtest Playable + Store Visibility Hidden; hand keys directly to testers). Public Coming Soon page is gated on the beta art read, not now.

## S1 cosmetic sourcing — closed 2026-06-10 (CC to implement)
The S1 asset audit is done; sourcing is locked at **$29.35** (Suburbia $19.95 + ice/fireball FX
$9.40). Full reasoning in `design/SEASON.md` + `notes/board_obstacle_model.md`. CC tasks:
- **Suburbia pack:** ground tile sliced (red-brick `fill-texture` → `src/assets/maps/suburbia_tile.png`)
  + `board_toybrick` retagged → `board_suburbia` in `cosmetics_catalog.gd` ITEMS + TRACK tier 26, path-dirt
  set to grey for contrast — **done 2026-06-10 (CC), verified in preview.** *Still TODO:* tag each prop
  with a footprint for the obstacle library (Phase 3, below).
- **Obstacle determinism — GATE CLEARED ✓ (2026-06-10, CC):** verified `match_room.gd:60` issues one
  `hash(match_id)` seed, broadcasts it to all clients via `START_MATCH`, and `map_generator.generate(seed)`
  derives the entire map incl. every obstacle; `resim.gd` rebuilds the same map from `record["seed"]`.
  Deterministic + shared + resim-fed — safe to build the Suburbia-scoped obstacle library (art free over a
  fixed footprint, varying footprint rides the seed). *(Still promote the rule to `decisions.md`.)*
- **Boards from owned:** `board_forest` **done 2026-06-10 (CC)** — baked pine-green recolor of Summer →
  `forest_tile.png` (no runtime tint: `collection.gd:556` rule forbids tinting painted sprites);
  `board_beach` **BLOCKED** — Tiki art not uploaded yet (`art:""`).
- **Mob recolors (green/purple/cyan, tiers 2/11/21):** re-base off the dropped Monster Maker kit
  onto a runtime tint of the owned **undead** default.
- **Aquatic mobs (fish/starfish/hammerhead, tiers 6/16/27):** owned, but never went through the
  top-down check — render and confirm perspective (plain side-profile **fish** is the risk;
  starfish/hammerhead read fine from above).
- **FX:** smoke ring (18) / lightning (24) / explosion (29) come off the **owned** FX bench (tower
  packs); dark (30) is a recolor; **Fire (10) + fireball trail (14) + Ice (20) use purchased bespoke
  FX** (fireball $0.45 + ice $8.95).
- **Frames/banners authored, not bought:** wood frame (5) owned; Mint Choco banner (15) + Parchment
  frame (23) **authored from the owned Wood-UI kit** (single-hue outline art) — the $16.95 GUI kits
  are dropped (membership lapsed → full price, indefensible to extract one piece each).
- **Optional:** expose per-board path recolor (`road_renderer` already has the 3 Color exports) so a
  low-contrast ground can shift the path colour instead of needing new art.

## Deploy / ops (CC)
- **Deploy the beta module to the box:** the `BETA = true` switch (ranked_s0 + `trials_beta_*` boards + `LOBBY_FLOOR 2`) is implemented in the repo (2026-06-09: `index.js` + mirrored client flags `LeaderboardService.BETA` / `SaveData.BUILD_SEASON`) but the box still runs the old module — `scp deploy/nakama/data/modules/index.js` over + `docker compose restart nakama`. The launch revert (flip all three flags together) is documented at each flag site; the floor-4 lock lives in `notes/decisions.md`.

## CC — carried (not blocking; do as items are promoted)
- Export a **catapult PNG body** (`towers/catapult/` ships SVG only).
- **Import the S1 track art** into `src/assets/` as items are promoted — now mostly owned/authored/recolor per the sourcing block above; the only new art is the Suburbia ground + props. The Collection/Season screens render any item with `art:""` as a placeholder tagged "import pending"; `cosmetics_catalog.gd` is the single place to point art at. Skins live in the client render layer only — never route equipped-skin state through the match record (breaks re-sim determinism).
- **Apply equipped skins in the real match** (render layer): read `SaveData.equipped_cosmetic()` at match build, **LOCAL board only** (opponents keep defaults — their skins aren't known and must never ride the match record). Shared resolver = `CosmeticsCatalog.texture_for/tint_for`.
  - **Board biome — DONE 2026-06-10 (CC):** `map_loader._build_board` swaps the ground texture for `is_local`; verified in-match (`match_shot.tscn`, reusable harness). resim builds with `local_index=-1` so it never reads skins → determinism untouched.
  - **Tower body + projectile tint — DONE 2026-06-10 (CC):** `map_loader` resolves skin/tint for `is_local` → `build_controller` (towers + ghost) → `tower` (width-fit scale matching the preview; reload swap kept only for the default arrow) → `projectile` (non-crit modulate; crit keeps its gold tell). Verified crystal towers render in-match; sim_harness round-trip + determinism green.
  - **Remaining:** none with art in hand (tower/board/proj done; mob + zone excluded below).
  - **Excluded by design (flag):** **zone tint** clashes with the type-color legibility pillar ("red tower on red zone") — needs a design call before tinting in-match; **mob sprite** is blocked (skin art not imported / aquatic perspective unchecked, and recolor-via-tint hits the no-tint-painted-sprite rule).
- Build the **board-sticker render layer:** chrome-edge placement, runtime outline tint per tier, animated multi-color stroke for Masters; toggle; never overlaps the play area.
- **Post-match Season nudge** (COSMETICS.md: Season "surfaced everywhere") — small tier/progress chip on the Trials/Ranked match-end panel once tasks award points. UNBLOCKED 2026-06-10: the task runtime now lands points at match end and `TaskCatalog.record_match()` returns `{points, completed}` (the chip's data) — just needs the panel UI.
- **Season task panel** (additive): `TaskCatalog.task_list(SaveData.tasks())` already returns the 15 tasks with progress/target/payout/done for a future tasks screen; not built yet (the Season screen shows track tiers, not the task list).
- **Steam identity into the profile card** — `collection.gd._player_name()` falls back to the Nakama username; swap to Steam persona + avatar when Steam auth lands.
- **Tutorial anchor check (playtest):** beat anchors (`score`/`respawn`/`tower`/`board`) resolving in the new right-rail HUD isn't auto-testable; `tutorial_callout._anchor_panel` still maps `score`/`upgrade_panel` to the OLD top-bar/right-dock positions — re-check against the rail layout in playtest. Also M1's blocking opener pause→resume.
- **Low-pri cosmetic:** `design/DESIGN_MODES.md` schema block still uses literal field names `bronze_threshold`/`silver_threshold`/`gold_threshold` (these are the 1/2/3-star cutoffs). Rename to star-N someday; not worth a churn now.

## Own session (large)
- **Full GTM / marketing plan** — `notes/gtm.md`. **Steam-gated end to end:** the public page is gated on the beta art read, which is gated on people playing the build, which is gated on Steam. No meaningful GTM work survives upstream of the art read (this kept resurfacing as here-doable — it is not). Capsule (~$250+) is the one paid item worth prioritizing once the page is unblocked.
- **Steam closed-beta ops pipeline** — mechanics are designed (`notes/beta_design_brief.md`); what remains is the Steam-side build pipeline: App ID, Playtest app, Win+Mac export presets, steampipe. Blocked on verification clearing.

## Blocked on playtest data
- **Star-threshold calibration** (Campaign + Trials).
- **Absolute task thresholds** — `TaskCatalog.THRESHOLDS` ships playtest-gated stand-ins (the structure/payouts are locked; only the X integers move). Tune alongside the star thresholds.
- **Economy/supply re-tune** for the 25×16 board.
- **Campaign tuning integers** — supply/rounds/mobs/zone-mix for the five missions; wait on the 25×16 retune + real scores.
- **PVP seed-convergence** — shared-seed ranked could converge to identical mazes; eyeball in playtest.
- **Aquatic-mob perspective** — confirm fish/starfish/hammerhead read on a top-down board (render check above; settle in playtest if borderline).

## Parked — additive, not now
- **Generic nature-prop obstacle buy** — fixes "same few props" on Forest/Beach/Summer (Suburbia only covers its own board). Buy deliberately if the alive-levels payoff proves out in playtest.
- **Individual-while-grouped Trials scoring** — a future vote letting grouped players each post to Solo instead of team score. Group size = the board for now.
- **Ranked ready-check** — ships off; flip on only if AFK-poisoning shows in beta.
- **Match reconstruction after coordinator crash** — model is re-simmable, but crash currently voids with no LP instead.

## Drift / audit
- (Resolved 2026-06-10: S1 cosmetic sourcing audit — board kill-criterion corrected, Suburbia swapped for toy-brick, sourcing re-priced to full freight, tiers renamed.)
- (Resolved 2026-06-10: `multiplayer_architecture.md` verdict column fixed — banner added, Steam-relay → skipped, Dedicated → deployed.)
- (Resolved 2026-06-09: 4-digit room-code sweep, grid-figure sweep, 10-mission refs, title, stale HUD subsection.)
