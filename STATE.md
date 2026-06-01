# State

Last updated: 2026-05-31

---

## Current focus

**Render-fix re-verify CLOSED (2026-05-31).** User playtested the build-mode hover overlay on a dense map on the real renderer — memory holds, no leak/spike. The MUST-reverify item from round-2 fixes is resolved; the `Line2D` fallback is no longer needed unless a future regression appears.

**Active tracks (user-directed 2026-05-31):** (1) finish campaign missions 2–10; (2) get multiplayer (PVE group + PVP) working. Both have open design — see scoping below.

**Playable through `8173085` (pushed to origin/main).** The game now boots through first-launch → home → and into either **Campaign** (mission 1 authored) or **solo PVE** (daily seeded Scale 1–5 generated maps). Full match loop, pause menu, settings, breakpoint-tuned upgrades, partial-score saving. Map resource framework + real procgen + UI/navigation all landed and verified.

**Most likely next steps:** more campaign missions; PVE backend (weekly/monthly windows, lobbies, leaderboards — deferred); audio (bus layout + sounds, which would make the Music/SFX sliders live); threshold calibration from real scores; or PVP. Open render fallback: if the build-mode overlay ever regresses on perf, replace the immediate-mode `_draw` dashes with a `Line2D`.

---

### Session log (chronological, most recent first)

**Multiplayer Phase C — baseline bot AI done & verified (2026-05-31), not committed.** Non-local boards now play themselves, so a match has real opponents (solves cold-start).
- `bot_controller.gd` (NEW), one per non-local board, acts only during the build phase, one throttled action per tick (spreads out, reads naturally when spectated). Two behaviours: (1) **maze building** — greedily place the tower that most lengthens the mob path, from a bounded sample (`SAMPLE_K=12`) of placeable cells adjacent to the existing maze/path (seeded from entry/exit/checkpoints on an empty board), up to a round×`difficulty`-scaled target; (2) **upgrading** — once at target / out of useful placements, spend remaining gold upgrading a random tower in a preferred-stat order (damage/attack-speed weighted). `difficulty` field present for later tiers. Stops if `board.is_active()` is false (PVP elimination, Phase D).
- `build_controller.bot_place_tower(cell)` (NEW) — validate + afford + spend + place, same checks as the human input path; the bot drives placement through it.
- Wired in `map_loader._build_board`: each non-local board gets a BotController. (Confirmed projectiles parent under `get_parent()` = the board container, so they render at the right offset — the Phase-B caveat was a non-issue.)
- **Verified headless** (throwaway harness, deleted): a 2-board match (local idle + 1 bot) — the bot placed 9 towers, **lengthened its path** (3249→3396 px), bought 8 upgrade tiers, spent down to 5 gold, and never touched the local board; in the run its towers dealt 382 dmg / 3 kills **only on its own board** (local stayed 0/0 — no cross-board leak). Solo path re-smoked clean (exit 0).
- **Next:** Phase D — PVP ruleset: 100 lives / 800 pool, Model B pairwise lives transfers after each run phase (kill-difference based), elimination at 0, last-standing win + placement, "Find Match" entry that fills with bots. First playable = PVP vs 7 bots — and the first real multi-board launch to eyeball the spectator camera. Difficulty tiers for bots can come alongside.

**Multiplayer Phase B — DONE & verified (2026-05-31), not committed.** N-board lockstep + per-board zone scoping + the spectator camera. Solo is just `num_boards == 1` and renders exactly as before. The coordinator drives N independent boards in lockstep.
- `map_loader.gd` restructured: `build_match(host, map, num_boards)` makes one coordinator + N board containers (each a self-contained sim subtree: own background/zones/markers/obstacles/spawner/build_controller/BoardState + **its own mobs array**). Board 0 is the local player at world origin (so mouse/cell math is exact); extra boards are offset right (`_board_offset`, stride = grid + 6 tiles) — rendering-separation groundwork for the arena view. `load_into(host, map)` stays the solo entry (calls `build_match(…, 1)`). On-screen UI (HUD/panels/pause_menu) binds to board 0 only.
- **Bonus zones scoped per board** (the global-group cross-contamination I flagged in Phase A is fixed): `BoardState.bonus_zones` holds the board's zone nodes; `tower.gd` and `mob.gd` query their own board's zones (via injected `board` ref; `tower.board` set in `build_controller._place_tower` before `_ready`), falling back to the global group only if no board is set. NOTE the zone math is in container-LOCAL coords, so offsetting boards alone would NOT have isolated them — explicit scoping was required.
- `build_controller.interactive` flag: non-local boards get a controller with no input/ghost/upgrade-panel/hint/overlay (process+input disabled), but still `recompute_path()` so their spawner has a wave path.
- **Verified headless** (throwaway harness, deleted): built a 3-board match on mission_04 — all 3 ran in perfect lockstep (identical alive counts), a round advanced ONLY when every board drained to 0 (gate assertion never tripped), each board had its own distinct 3-zone set, and the match ended together at round 3. Separately smoke-tested the solo path (`prototype.tscn` → `load_into`, 150 frames, exit 0, no errors) — no regression.
- **Spectator camera done:** `arena_view.gd` (NEW) — a Camera2D created only when `num_boards > 1` (solo gets none, framing unchanged). Frames ONE board at a time (hides the others to avoid neighbour bleed, centers + zoom-to-fit). Build/post-match → your board only; run phase → cycle every board via Tab / ←→ with a spectate label. Wired in `build_match` (collects board containers). Verified headless: solo has no arena/camera and its board stays visible; multi creates arena+camera, spectate cycles 0→1→2→0 with exactly one board visible, and a build phase snaps back to the local board.
- **Caveat:** the spectate camera's *visual framing* (zoom/centering) is logic-verified only — no real-app multi-board launch exists yet (needs an MP entry point, Phase D, or a debug launch) and headless can't render. Also TODO when bots place towers (Phase C): confirm projectiles parent under the board container so they render at the right offset.
- **Next:** Phase C (bot AI — make the dummy boards actually maze/upgrade/spend) → Phase D (PVP ruleset: lives, pairwise transfers, elimination, last-standing; first playable = PVP vs 7 bots, which also gives the first real multi-board launch to eyeball the camera).

**Multiplayer Phase A — coordinator/board split done & verified (2026-05-31), not committed.** The enabling refactor for local-sim multiplayer (plan: build the full MP experience vs bots in one process, layer netcode on later — networking/hosting still deferred). The match is now **N independent boards + one MatchCoordinator** that owns the shared clock and (later) cross-board resolution. Solo = a coordinator with one board, so the single path serves every mode.
- `match_coordinator.gd` (NEW) — owns round_num/phase/build_timer/max_rounds, the global mob-HP curve, the start-now gate, the run-phase-complete gate (waits for ALL active boards' trains to exit), round advance, match end, and a `_end_round` hook where PVP transfers / PVE aggregation will land. Emits phase_changed/round_changed/build_timer_changed/match_ended.
- `round_manager.gd` slimmed to per-board **BoardState** (kept the filename/`class_name RoundManager` and the `round_manager` var name across consumers to avoid churn — it now means "this board"). Owns gold/economy/damage/kills/spawner/run-detection + lives flag (`eliminated`, for PVP). **Proxies** the clock fields (phase/round/build_time/max_rounds/match_over read from the coordinator) and **forwards** the coordinator's clock signals, so HUD/build_controller/upgrade_panel/panels needed ZERO changes. New methods the coordinator drives: `start_run`/`is_run_done`/`settle_round`/`is_active`.
- `mob.gd` — replaced the `call_group("round_manager", ...)` **broadcast** (which would credit every board) with a direct `mob.board` reference injected by the spawner. `spawner.gd` carries `board` and injects it per mob. `map_loader.gd` builds the coordinator + one board and registers it.
- **Verified headless** (throwaway harness, deleted): a real match built via map_loader ran the full build→run→round-advance→match-end cycle (rounds 1→2→3→ended), gold accrued via settle_round (250→421), and **per-board damage/kill crediting confirmed** (775 dmg / 7 kills to the right board). Used the game's own 3x fast-forward (HUD `_apply_time_scale` re-clamps `Engine.time_scale` every refresh — can't override it externally; FF caps at 3x).
- **Known Phase-B item:** `mob.gd:_current_speed` still queries the global `bonus_zones` group — fine for one board / spatially-separated boards, must be board-scoped when boards coexist.
- **Flagged for a real-renderer check (NOT a refactor regression):** under 3x fast-forward + heavy farming, the headless run exited early (~frame 600) — looks like death/damage-FX accumulation; unverified whether it affects the real renderer (could be a headless dummy-renderer artifact). Possibly related to the earlier run-phase FX churn work.
- **Next:** Phase B — coordinator drives N boards in lockstep (human + idle dummies), spectate-switch to view a board; then Phase C bots, Phase D PVP ruleset (first playable: PVP vs 7 bots).

**Campaign missions 2–10 authored (2026-05-31) — AWAITING PLAYTEST, not yet committed.** The campaign is now content-complete (10/10 missions playable):
- Curriculum locked & recorded in `DESIGN_MODES.md` ("Mission curriculum"). M1 is the big sandbox intro; each later mission isolates one decision on a rising curve; M10 is the capstone bridge to PVE Scale 5. Crit/multishot taught via upgrades (no crit/multishot zones exist — only DAMAGE/ATTACK_SPEED/RANGE/SLOW).
- `mission_02.tres`…`mission_10.tres` hand-authored (same schema/workflow as mission 1). Registered in `scene_manager.gd` `CAMPAIGN_MISSIONS` (all 10). `campaign_select.gd` is data-driven off `has_campaign_mission`, so the "Coming soon" cards auto-flipped to playable — no UI change needed.
- Thresholds derived from mission 1's approved ratio (silver ≈ 1.875 × supply × rounds; bronze ⅔, gold 4⁄3), **soft/uncalibrated** — need playtest calibration like the PVE thresholds.
- **Verified headless** (throwaway harnesses, since deleted): a data harness confirmed all 10 pass field/bounds/threshold checks AND have a valid base path (entry→checkpoints→exit) with obstacles in place and zero towers; a loader smoke test instantiated the real `prototype.tscn` on M8 (12 obstacles) and M10 (6 zones/3 cp/100 supply) and ran 120 frames each with zero errors. Note: `-s` script runs don't init autoloads — used the documented main_scene-swap pattern for the smoke test (see [[reference-godot-headless-verify]]).
- **Next on this track:** playtest 2–10 for feel + threshold calibration, then commit. Then multiplayer (user picked campaign-first; MP approach = "no preference", my recommendation stands: build the full MP experience vs bots in one process first, layer netcode on later — networking/hosting model still deferred).


**Map resource framework built and verified (Claude Code, 2026-05-30).** The mission/map resource architecture from `DESIGN_MODES.md` is now implemented in Godot:
- `GameConstants` autoload holds all global tuning (economy, build timings, mob HP growth, tower base stats, crit/multishot caps, upgrade ramp, lives). Registered in `project.godot`.
- `MapResource` + `ZoneDefinition` resource schemas (`src/resources/`). Per-map values (grid, layout, obstacles, zones, supply, rounds, thresholds) live here.
- `map_loader.gd` builds the live scene from any MapResource; `main.gd` is now a thin host that loads `mission_01.tres` via the loader.
- `mission_01.tres` hand-authored as the first campaign mission — validates the authoring workflow.
- `map_generator.gd` is a **stub** (returns a valid MapResource per the scale table; real procgen + constraint validation still TODO).
- All scripts refactored off hardcoded magic numbers. Verified with a headless run through build phase → run phase → round transition, zero errors.

**Note:** the locked schema stores obstacles as bare cells (`obstacle_cells: Array[Vector2i]`), so the textured multi-tile props (cars, dead trees) from the prototype are gone — each obstacle cell now renders a single debris prop. If richer obstacle visuals matter, the schema needs an `ObstacleDefinition` sub-resource (texture + footprint) — that would reopen the locked MapResource schema.

**UI/navigation Phase 1 done (2026-05-30).** Built the core navigation layer:
- `SaveData` autoload — JSON save at `user://save.json`; holds `first_launch_done` + campaign medals. `SceneManager` autoload — owns transitions, carries the chosen `MapResource` into the match via `pending_map`.
- `boot.tscn`/`boot.gd` — entry point (now `run/main_scene`); first launch sets the flag and drops into mission 1, every launch after opens the home screen.
- `home_screen` (Campaign live; PVE/PVP present but disabled — multiplayer deferred) and `campaign_select` (missions 1–10, all unlocked, best medal per mission; only mission 1 authored, 2–10 shown "Coming soon").
- `main.gd` now reads `SceneManager.pending_map` (falls back to mission 1 if launched directly). Match-end + win-panel exits route through `SceneManager.goto_home()` / `restart_current_match()`; campaign medals persist via `report_match_result`.
- Verified headless: first-launch→mission, returning→home, campaign_select builds, save file writes correctly.

**UI/navigation Phase 2 done (2026-05-30).** Pause menu (`pause_menu.gd`, built by `map_loader`):
- Owns the full Esc priority stack as the single arbiter — `build_controller` no longer handles Esc (exposes `is_build_mode`/`is_upgrade_panel_open`/`close_upgrade_panel`/`exit_build_mode` for the menu to drive). Order: upgrade panel → build mode → pause menu; Esc again resumes.
- SP (campaign / solo PVE) pauses the tree while open; MP does not (reads `SceneManager.current_is_multiplayer`). MP shows "Quit Match" with a context-aware PVP/PVE message; SP shows Restart + Quit to Menu. Both destructive actions go through a confirm dialog.
- Restart → `SceneManager.restart_current_match()`, Quit → `goto_home()`. Settings button present but disabled (Phase 3).
- Verified headless with a throwaway input harness: Esc toggles pause on/off and the quit-confirm dialog appears. Also fixed a real bug found via stderr capture — `boot.gd` called `change_scene_to_file` during `_ready` ("parent busy"); now deferred. See new memory [[reference-godot-headless-verify]].

**UI/navigation Phase 3 done (2026-05-30) — UI layer complete, AWAITING PLAYTEST.** Settings:
- `SaveData` now stores a `settings` dict (master/music/SFX volume, default game speed, fullscreen, resolution index, damage numbers), backfilled from `DEFAULT_SETTINGS` on load, applied at startup. `apply_audio` (guarded by bus existence — no Music/SFX buses yet, so those are inert until audio is added), `apply_display` (DisplayServer fullscreen + windowed resolution).
- `settings_panel.gd` — reusable CanvasLayer overlay (process ALWAYS, layer 40) openable from home screen and pause menu. Sliders/option buttons/checkboxes apply live; saves to disk on close. No own Esc handler — the opener (pause menu in-match, home screen otherwise) closes it on Esc, top of the priority stack.
- Default game speed applied via `Engine.time_scale` at match start (`main.gd`); reset to 1× on menu scenes (`SceneManager`). Damage-numbers toggle gates `mob.gd._spawn_damage_number`.
- Verified headless (stderr captured): boot paths, match+pause+settings build, settings round-trip (set→save→reload→read-back), and the full run phase with the damage-numbers gate. Save reset for a clean first-launch test.

**Committed** `66c5d17` on `main` (playtested & approved, 2026-05-30) — one cohesive commit (phases commingled within shared files, so a clean 4-way split wasn't practical). **Not yet pushed to origin.**

**Procgen done (2026-05-30).** `map_generator.gd` is now a real seeded generator (was a stub):
- Entry/exit on left/right edges; serpentine checkpoints (re-rolled toward a min path-length ratio); obstacles scattered and each validated against the pathfinder (kept clear of edge funnel); bonus zones with the first planted on the path corridor (reachability) and the rest enforcing ≤1 overlap (no 3-way overlap); per-map thresholds derived from path length (soft, tunable). Scale table drives supply/checkpoints/zones/mobs/rounds per tier. PVP omits thresholds.
- Verified via a throwaway harness: 100 maps (tiers 1–5 × 20 seeds) passed every DESIGN_MODES procgen constraint; determinism confirmed; a generated map loads + builds through `map_loader` (same path as campaign). Path/straight ratio avg 1.36.
- **Not yet reachable in-app** — there's no PVE/PVP entry to launch a generated map. The generator is validated infrastructure; wiring a playable PVE-solo entry (map select → generated map → match) is the obvious next step if you want to feel it in the real app.

**Playtest fixes round 2 (2026-05-31) — shipped in commit `8173085`, pushed.** Four more from the second PVE playtest (render fix confirmed in-game by the user):
1. **Partial scores count** — bowing out mid-match now records the current score. `SceneManager.report_match_result(damage)` computes the medal itself; new `leave_match_to_home(damage)` records-then-home, wired into the gold-reached popup (`win_panel`) and the pause-menu quit. Best-kept storage means a partial never beats a full run (the user's no-risk call). Pause SP quit message updated ("Your score so far is saved").
2. **Quit Game from main menu** — `home_screen` bottom-left button → `get_tree().quit()`.
3. **HUD "0/0" at start fixed** — the controller emits `towers_changed` before the HUD is in the tree, so the HUD now seeds count/cap from the controller on connect (shows e.g. `0 / 60`).
4. **Memory/near-crash — root-caused to render-side path overlay.** User confirmed it happened **while hovering in build mode** (no mobs/firing). Measured the hover path headless (dense 80-tower maze, 600 frames of validity + projected-path pathfinding): objects + memory **dead flat at 29.3 MB** — so the pathfinder/logic does NOT leak. Real cause: `build_controller` repainted the whole maze path **every frame** with `draw_line(antialiased=true)` — hundreds of AA segments/frame in the GL-compat renderer, and doubling supply made the maze path much longer, so it spiked. Fixes: **dropped antialiasing** on the dash draw and **throttled the overlay repaint to ~30fps**. Also kept (separate, still worthwhile): `mob.gd`/`death_fx.gd` now share one `SpriteFrames` instead of rebuilding per spawn/death — reduces run-phase churn, though it was NOT the hover cause.
   - **MUST re-verify on the real renderer**: hover in build mode on a dense Scale 4/5 map and watch memory. If it still climbs, the fallback is to replace the immediate-mode `_draw` overlay with a `Line2D` (set points once on path change) instead of redrawing every frame.

All code verified headless (builds clean; HUD cap correct; firing+deaths work with shared frames; partial score records; hover-path memory flat). The render fix itself can't be measured headless (dummy renderer). See [[reference-godot-headless-verify]].

---

**Playtest fixes round 1 (2026-05-31).** Four changes from the first PVE playtest, on top of the PVE-solo work below:
1. **Supply doubled** — PVE scale table now 20/40/60/80/100 (was 10–50); campaign `mission_01` cap 50→100. The 40×22 map was too big to maze with the old supply. (Generated thresholds scale with supply, so they roughly doubled too — still soft.)
2. **Checkpoint count shown** on PVE map cards alongside rounds/supply/zones/mobs.
3. **Upgrade panel clamped on-screen** (`upgrade_panel._position_near`) — flips to the tower's left near the right edge and clamps into the viewport, so towers near any edge no longer hide part of the panel.
4. **Breakpoint-tuned upgrades** — replaced the flat +10%/tier with per-stat increments in GameConstants. Damage `0.34`/tier anchored to base-mob (100 HP) shots-to-kill: tier 1 → 3 shots, tier 3 → 2, tier 9 → 1 (verified via harness). Attack speed `0.15`/tier (extra-shot crossings sooner; placement-dependent). Range stays `0.10`. Crit/multishot unchanged (already discrete/probabilistic).

All verified headless (builds clean; breakpoint table confirmed). Awaiting the user's re-test of feel before commit.

---

**PVE-solo (2026-05-30, shipped in commit `8173085`).** Generated maps are now playable:
- Home `PVE` button enabled → `pve_select` scene: 5 maps (Scale 1–5) seeded from the current date (`hash(window_date) + tier`), so the set is stable per day and changes daily — locally, no backend. Each card shows rounds/supply/zones/mobs + local best score. `SceneManager.start_pve_map` → match (solo = single-player pause variant).
- `SaveData` stores local PVE best scores per `window_date|tier` (`record_pve_score`/`best_pve_score`); `SceneManager.report_match_result` records PVE scores (campaign still records medals).
- Reuses generator + loader + match + pause + settings unchanged. Verified headless: select builds 5 maps, a generated map loads (24 nodes), score round-trips.
- **Caveats:** (1) generated thresholds are very high/uncalibrated (Scale 3 gold ~656k) — fine for PVE since it's high-score-driven and medals are stretch goals, but needs playtest calibration; (2) the campaign-style gold-reached early-win popup is technically still active in PVE but effectively never fires given the high thresholds (leave unless it misbehaves); (3) only the daily window is implemented (weekly/monthly + leaderboards/lobbies remain deferred).

**Next build focus:**
- Threshold calibration once real PVE scores exist (lower `THRESHOLD_COVERAGE` or rework formula).
- Audio bus layout + actual sounds (would make Music/SFX volume sliders live).
- Full PVE (weekly/monthly windows, lobby, leaderboards) and PVP backends — deferred (multiplayer).

---

## UI/Navigation design session — 2026-05-30

Key decisions locked:

### First-launch flow
- Single boolean `first_launch` written to save data on first launch
- First launch: skip home screen, load mission 1 directly
- Player can Esc → Quit to Menu at any time — lands on home screen
- No requirement to complete mission 1; flag is set on launch, not completion
- All subsequent launches go straight to home screen

### Home screen
- Two primary buttons: **PVE** and **PVP**
- Season progress bar + tier badge: slim, top of screen, ambient not dominant
- Campaign: tertiary button, clearly secondary — it's a tutorial, not the product
- Settings: tucked away
- All in-match exits (win modal, pause menu quit) land here

### Campaign navigation
- All 10 missions unlocked from the start — no sequential gating
- Difficulty curve is guidance, not a gate

### PVE navigation
- Solo player: map select → straight into match
- Group: map select → brief lobby (invite + team/individual vote + ready up) → match

### PVP navigation
- One button: Find Match → queued

### Pause menu
- Esc priority stack: upgrade panel → build mode → pause menu
- Single player: pauses tree; options: Resume / Settings / Restart / Quit to Menu
- Multiplayer: does NOT pause tree; options: Resume / Settings / Quit Match
- Restart only available in single player
- Both Restart and Quit to Menu require confirm dialogs
- PVP quit dialog: "You will be eliminated and your lives will leave the pool"
- PVE quit dialog: "Your score will not be posted"
- Settings: master/music/SFX volume, default game speed, fullscreen, resolution, damage numbers toggle

### Specialization removed
- No specialization, no evolution, no milestone effects — ever
- May revisit post-launch if players explicitly request it
- Removed from DESIGN.md; added to anti-goals

---

## Mode design session — 2026-05-30

Full mode design locked. Key decisions: Campaign (solo, 10 missions, tutorial function), PVE (1–4 players, 5 maps per window, scale 1–5, daily/weekly/monthly), PVP (8 players, solo queue, pairwise lives transfers, LP ranking, seasonal resets), Seasons (free battle pass, cosmetic rewards, Masters rank number permanent on cosmetic), MapResource architecture, GameConstants autoload. All in `DESIGN_MODES.md`.

---

## Next step

**For Claude Code:** ✅ The 7-step map-resource framework below is DONE and verified (2026-05-30). Kept here for reference.

1. ✅ `src/resources/game_constants.gd` — autoload singleton, all global magic numbers moved in
2. ✅ `src/resources/map_resource.gd` — MapResource schema (note: `Window` enum renamed `WindowType` — shadowed native class; `bonus_zones` left untyped to dodge the cross-script typed-array pitfall)
3. ✅ `src/resources/zone_definition.gd` — ZoneDefinition sub-resource
4. ✅ `src/scripts/map_loader.gd` — reads MapResource, builds scene
5. ✅ `main.gd` — thin host, loads `mission_01.tres` via loader
6. ✅ `src/campaign/mission_01.tres` — first campaign mission, hand-authored
7. ✅ `src/scripts/map_generator.gd` — stub (real procgen TODO)

Next candidates (pick one): real procgen in `map_generator.gd` per the "Procgen constraints" spec; or the home-screen / mode-select scene so `main.gd` stops hardcoding mission 1.

**For this Claude (design):**

- Leaderboard backend design (captured in `notes/leaderboards.md` — needs updating with mode decisions)
- PVP LP curve (exact points per placement TBD)
- Season pass point values and milestone thresholds
- Damage threshold calibration (needs real playtest data)
- Soft caps for damage / range / attack_speed upgrade stats

---

## Recently touched files

- `src/resources/game_constants.gd` — NEW autoload, all global tuning
- `src/resources/map_resource.gd`, `zone_definition.gd` — NEW resource schemas
- `src/scripts/map_loader.gd`, `map_generator.gd` — NEW (generator is a stub)
- `src/scripts/main.gd` — gutted to a thin loader host
- `src/scripts/round_manager.gd`, `tower.gd`, `mob.gd`, `build_controller.gd`, `hud.gd`, `match_end_panel.gd`, `win_panel.gd` — refactored off magic numbers / old consts
- `src/campaign/mission_01.tres` — NEW first mission
- `src/scripts/save_data.gd`, `scene_manager.gd`, `boot.gd`, `home_screen.gd`, `campaign_select.gd` — NEW (UI/nav Phase 1)
- `src/scenes/boot.tscn`, `home_screen.tscn`, `campaign_select.tscn` — NEW screens
- `src/scripts/main.gd` — reads SceneManager.pending_map; `win_panel.gd`/`match_end_panel.gd` route exits home
- `src/scripts/pause_menu.gd` — NEW (UI/nav Phase 2); `build_controller.gd` — Esc handling removed, public hooks added; `boot.gd` — deferred routing; `map_loader.gd` — instantiates pause menu
- `src/scripts/settings_panel.gd` — NEW (UI/nav Phase 3); `save_data.gd` — settings storage + apply; `home_screen.gd`/`pause_menu.gd` — Settings button + Esc-close wired; `main.gd`/`scene_manager.gd` — game-speed time_scale; `mob.gd` — damage-numbers gate
- `src/project.godot` — GameConstants + SaveData + SceneManager autoloads; main scene now boot.tscn
- `STATE.md` — this file

---

## Open questions / blocked on

### Implementation (Claude Code)
- Procgen algorithm for PVE/PVP map generation — constraints specced in DESIGN_MODES.md, algorithm TBD
- Bot behavior in PVP private lobbies — deferred
- Eliminated player maze handling in PVP — deferred
- Networking/hosting model — deferred
- Home screen scene implementation — design locked, implementation not started
- Pause menu scene implementation — design locked, implementation not started
- First-launch flag system — design locked, implementation not started

### Design (this Claude)
- Leaderboard backend design
- PVP LP curve
- Season pass point values and milestone thresholds
- Damage threshold calibration — needs playtest data
- Soft caps for damage / range / attack_speed

### Locked design decisions
See `DESIGN.md` and `DESIGN_MODES.md`.
