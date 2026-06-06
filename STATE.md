# State — Wend
Last updated: 2026-06-05

> **Read order:** `claude-rules.md` → `RULES.md` → this file → `notes/open_items.md` (full backlog) → only the specific file the task needs.
> **History:** older session logs were moved to `STATE_ARCHIVE.md` — reference only, don't load unless you're digging into a past decision.

---

## ⚠️ Recent reversals — do NOT act on stale instructions
The archive (and older memory) describe a **mobile-first** direction. That is **DEAD as of 2026-06-05.**

- **Platform: PC/Mac-first. Mobile NEVER** (console if the game succeeds; mobile only revisited on viral success). A mobile build would be a *fork* — different board, different leaderboard, different game — not a port, because you can't resize the board and keep crossplay.
- **Board is going UP to ~23×14** (~+50%, ~66px tiles), **reversing the 20×11 mobile shrink.** The old "design for the smallest screen / rescale campaign to 20×11" plan is superseded: the board **grows**, and campaign `.tres` rescales to the **new** size, not 20×11. Final tile count pending the user's feel-check of `notes/mockups/inmatch_board_fullsize_1920.html`.
- **In-match UI:** current spec is the **2026-06-05 mockups** — recessed dark-grass surround + bright bounded board arena, flex layout, right inspector dock, redesigned victory panel. This **supersedes the earlier full-bleed-grass mockup**. See `notes/mockups/`.
- **Pricing: $10–15 (PC band)** — the old $5 was the mobile number. Saves = **Steam Cloud**.

---

## Name
**The game is "Wend"** (locked 2026-06-05; confirmed clear on Steam). Placeholder was "Maze Battle TD." Genre signal goes in a subtitle/tagline ("Wend — a maze battle TD"), not the name. **Player-facing mode names: "Trials" (PVE), "Ranked" (PVP).**

## Current focus
**Dedicated server is LIVE (2026-06-06).** Headless Godot match server deployed to the **Hetzner CPX11, Ashburn** box at **`178.156.171.215`**, listening on **UDP 8771**, running under systemd (`wend-server.service`, enabled + auto-restart). Verified reachable end-to-end: an external ENet client completed the handshake through the Hetzner firewall. Deploy kit + exact ops commands in `deploy/` (`README.md`, `deploy.sh`, `wend-server.service`). One match per server for now (Option A); concurrency is the later Option-B step. See `notes/server_decision.md`, `notes/remote_beta_plan.md`, `notes/multiplayer_architecture.md`.

Remaining for M1: a real **2-client cross-network match** (full game clients, not the raw probe) end-to-end — needs two humans/devices on different networks. ~~Bake the IP into `lobby.gd`~~ DONE 2026-06-06: `DEFAULT_SERVER = "178.156.171.215"` (env-overridable via `MBTD_SERVER=127.0.0.1` for local-server dev). Then M2 (Google Play internal testing) / the UI+board work below.

The 2026-06-05 design direction (reversals above) governs the next UI/board work.

## Last session (2026-06-06 — CC implementation: board + in-match UI)
Big build session. **Board → 25×14** (engine constants + all 10 campaign `.tres` rescaled from the 20×11 originals via `src/tools/rescale_campaign.gd`; generated maps auto-grow). **In-match UI rebuilt to the v3 bounded layout** (recessed dark surround + bright bordered board, reserved top/bottom bars + permanent right inspector dock, floating drawer → docked content-height inspector). **Victory screen redesigned** (stars, comma score, tier strip with ✓). Polish pass: board floats clear of the bars with balanced top/bottom gaps, path/road clamped on-board (no surround spill), drop shadows halved. All verified by rendered captures (`src/tools/ui_shot.tscn` harness) + headless smoke test. See "Next step" for the per-fix detail. Prior design-session-2 wrap below is still the design-decision record.

## Earlier (2026-06-05 — design session 2, no code)
Knocked out a stack of open design items to clear the deck for CC. Resolved: **game name → "Wend"** (Steam-clear; unblocks the store page), **mode names → Trials / Ranked**, **PVE window cadence** (keep daily/weekly/monthly), **vertical slice** (reframed to the beta/demo, not a formal slice), **leaderboard group scoring** (per-team, separate boards by size), the full **PVP LP ladder** (new `notes/pvp_ladder.md` — MMR-anchored net-positive, Bronze→Masters, season behavior; numbers are playtest dials), **soft caps** (governed-by-economy, no change; revisit only if gold/rounds/supply/board-size shift — CC checks the live log then), and **accessibility/zone icons** (label+color+uniform-shape baseline; verified icons for speed/slow/damage, range stays label-only — no target glyph exists in the pack). Earlier same-day session 1 locks (PC-first, $10–15, Nakama, mazing pillar, etc.) already captured in `open_items.md`.

## Next step
- **CC:** Hetzner deploy DONE (server live). Board rescale **DONE 2026-06-06**: **25×14** (feel-check passed at 23×14, then widened 1 tile each side), `Grid.COLS/ROWS` + `MapResource` default bumped, all 10 campaign `.tres` rescaled from the 20×11 originals + threshold-scaled (one-off `src/tools/rescale_campaign.gd`, run 20→25), generated PVE/PVP maps auto-grow, headless smoke test green.
- **In-match UI rebuild → bounded layout DONE 2026-06-06** (v3 mockup): reversed the full-bleed `play_rect`, which now reserves top bar + bottom strip + a **permanent right inspector dock**; `map_loader` draws a recessed dark surround (screen-space CanvasLayer) + a bright bordered board sized to the grid; `tower_drawer` converted from a floating slide-in to a docked inspector (placeholder when nothing selected; `‹ hide` collapses it and the board reclaims the width via a `game_view.refit()`). Verified by rendered screenshot (`src/tools/ui_shot.tscn` capture harness). **Victory screen → redesigned DONE 2026-06-06** (`win_panel.gd`): ★★★ + "You won!" (no em-dash, no redundant stars line), comma score, and a tier strip showing the three thresholds with green ✓ on cleared ones (verified by screenshot). **Fixed 2026-06-06 (layout polish pass):** (1) inspector dock now content-height + top-aligned (`tower_drawer._relayout` uses `reset_size()`); (2) board floats clear of the bars (`play_rect`/`inspector_region` add a `board_margin` gap top+bottom, TOP_BAR_H bumped to 75); (3) board vertically balanced — `BOTTOM_STRIP_H` 96→87 so the gap to the bottom buttons == the gap to the top pills; (4) **path no longer spills off-board** — `build_controller._extend_offscreen` runs the road/mobs to the board edge (not OFFSCREEN_PAD beyond), and `road_renderer` dropped its `_with_stubs` one-cell extension; (5) drop shadows halved (`ui_style._flat`: shadow_size 7→3, offset 5→2). **Open polish (user's call):** inspector reads a touch dark-on-dark against the surround when empty; road's rounded end-cap slightly overhangs the board edge (switch to a flat cap if it bugs you).
- Still needs two humans: a real 2-client cross-network match.
- Deferred (separate): supply/economy re-tune for the bigger board, threshold calibration (both need playtest data).
- **DONE 2026-06-06 (CC chores):** ~~rename PVE→"Trials" / PVP→"Ranked"~~ (home_screen, pve_select + `DESIGN_MODES.md` label-pass); ~~copy `energy.png` + `waiting.png` into `src/assets/ui/icons/` + import~~ (landed, Godot-imported; *wiring into `bonus_zone.gd` zone labels is still TODO — the accessibility-icon pass*); ~~point `DESIGN_MODES.md` LP-curve line at `notes/pvp_ladder.md`~~. `art.zip` now gitignored.
- **Design (mostly their own sessions):** juice/game-feel pass · full GTM + Steam page (now unblocked by the name) · anti-cheat system · season-pass numbers · Trials group-lobby flow · onboarding for non-SC2 players · IP/legal framing.

## Recently touched files
- `src/scripts/grid.gd`, `src/resources/map_resource.gd` — board 20×11 → **23×14** (+ `grid_overlay.gd`, `leaderboard_panel.gd` fallback defaults)
- `src/campaign/mission_01..10.tres` — proportionally rescaled to 23×14 + thresholds ×path-ratio
- `src/scripts/ui_layout.gd`, `map_loader.gd`, `tower_drawer.gd`, `game_view.gd` — in-match UI → bounded v3 layout (surround + bordered board + docked inspector)
- `src/scripts/win_panel.gd` — victory screen → v3 redesign (stars, comma score, tier strip)
- `src/tools/rescale_campaign.gd` — **NEW**, one-off migration tool (re-runnable only from a 20×11 baseline); `src/tools/ui_shot.tscn`/`.gd` — **NEW**, windowed screenshot capture harness
- `notes/pvp_ladder.md` — full Ranked LP/MMR/tier/season spec
- `notes/open_items.md` — full backlog ledger, **start here for what's open** (8 items resolved this session)
- `notes/leaderboards.md` — group scoring locked per-team, window cadence resolved, Trials/Ranked names
- `RULES.md`, `PROJECT.md` — name (Wend) applied
- `notes/season_pass.md`, `notes/pvp_lobby.md`, `notes/server_decision.md`, `notes/gtm.md`
- `notes/mockups/inmatch_ui_layout_v3.html`, `inmatch_board_fullsize_1920.html`, `inmatch_juice_taste.html`

## Open questions / blocked on
Full per-item status lives in **`notes/open_items.md`**. Active right now: board final tile count (feel-check pending) · Trials group-lobby flow · anti-cheat (own session) · GTM/Steam page (own session) · season-pass numbers. Blocked on data: B/S/G threshold calibration, PVP seed-convergence.
