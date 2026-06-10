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

## Cosmetics — open forks (not blocking)
- **Confirm** the free Background Creator pack actually yields path tiles before relying on it for the board slot.

## Deploy / ops (CC)
- **Deploy the beta module to the box:** the `BETA = true` switch (ranked_s0 + `trials_beta_*` boards + `LOBBY_FLOOR 2`) is implemented in the repo (2026-06-09: `index.js` + mirrored client flags `LeaderboardService.BETA` / `SaveData.BUILD_SEASON`) but the box still runs the old module — `scp deploy/nakama/data/modules/index.js` over + `docker compose restart nakama`. The launch revert (flip all three flags together) is documented at each flag site; the floor-4 lock lives in `notes/decisions.md`.

## CC — carried (not blocking; do as items are promoted)
- Export a **catapult PNG body** (`towers/catapult/` ships SVG only).
- Import the **S1 track art** into `src/assets/` as items are promoted: Monster Maker recolors + fish/starfish/hammerhead mobs, forest/beach/toy-brick biomes, the FX kit pieces, wood/parchment frames, Mint Choco banner. The Collection/Season screens (built 2026-06-09) render any item with `art:""` as a placeholder tagged "import pending" — `cosmetics_catalog.gd` is the single place to point art at. Skins live in the client render layer only — never route equipped-skin state through the match record (breaks re-sim determinism).
- **Apply equipped skins in the real match** (render layer): tower body, board biome tiles, zone tint, projectile/FX tint, mob sprite — read `SaveData.equipped_cosmetic()` at match build, client-side only. The Collection preview board already demonstrates the mapping.
- Build the **board-sticker render layer:** chrome-edge placement, runtime outline tint per tier, animated multi-color stroke for Masters; toggle; never overlaps the play area.
- **Task-system runtime** (`notes/task_system.md`): 5 shapes × 3 cadences, counters off match events (Trials OR Ranked), payouts 120/600/2,400 → `SaveData.add_season_points()`. The Season screen + claim flow are live and waiting on this XP source. Absolute thresholds stay playtest-gated.
- **Post-match Season nudge** (COSMETICS.md: Season "surfaced everywhere") — small tier/progress chip on the Trials/Ranked match-end panel once tasks award points.
- **Steam identity into the profile card** — `collection.gd._player_name()` falls back to the Nakama username; swap to Steam persona + avatar when Steam auth lands.
- **Tutorial anchor check (playtest):** beat anchors (`score`/`respawn`/`tower`/`board`) resolving in the new right-rail HUD isn't auto-testable; `tutorial_callout._anchor_panel` still maps `score`/`upgrade_panel` to the OLD top-bar/right-dock positions — re-check against the rail layout in playtest. Also M1's blocking opener pause→resume.
- **Low-pri cosmetic:** `design/DESIGN_MODES.md` schema block still uses literal field names `bronze_threshold`/`silver_threshold`/`gold_threshold` (these are the 1/2/3-star cutoffs). Rename to star-N someday; not worth a churn now.

## Own session (large)
- **Finalize season-pass numbers** — `notes/season_pass.md` has a soft 8wk/30-tier/1000pt worked example; now the catalogue + slots + task system exist, the actual tier-by-tier reward mapping can be laid out. Upstream-clear.
- **Full GTM / marketing plan** — `notes/gtm.md`. **Steam-gated end to end:** the public page is gated on the beta art read, which is gated on people playing the build, which is gated on Steam. No meaningful GTM work survives upstream of the art read (this kept resurfacing as here-doable — it is not). Capsule (~$250+) is the one paid item worth prioritizing once the page is unblocked.
- **Steam closed-beta ops pipeline** — mechanics are designed (`notes/beta_design_brief.md`); what remains is the Steam-side build pipeline: App ID, Playtest app, Win+Mac export presets, steampipe. Blocked on verification clearing.

## Blocked on playtest data
- **Star-threshold calibration** (Campaign + Trials).
- **Economy/supply re-tune** for the 25×16 board.
- **Campaign tuning integers** — supply/rounds/mobs/zone-mix for the five missions; wait on the 25×16 retune + real scores.
- **PVP seed-convergence** — shared-seed ranked could converge to identical mazes; eyeball in playtest.

## Parked — additive, not now
- **Individual-while-grouped Trials scoring** — a future vote letting grouped players each post to Solo instead of team score. Group size = the board for now.
- **Ranked ready-check** — ships off; flip on only if AFK-poisoning shows in beta.
- **Match reconstruction after coordinator crash** — model is re-simmable, but crash currently voids with no LP instead.

## Drift / audit
- (Resolved 2026-06-10: `multiplayer_architecture.md` verdict column fixed — banner added, Steam-relay → skipped, Dedicated → deployed.)
- (Resolved 2026-06-09: 4-digit room-code sweep, grid-figure sweep, 10-mission refs, title, stale HUD subsection.)
