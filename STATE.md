# State — Wend
Last updated: 2026-06-07

> **Read order:** `claude-rules.md` → `RULES.md` → this file → `notes/open_items.md` (full backlog) → only the specific file the task needs.
> **History:** older session logs were moved to `STATE_ARCHIVE.md` — reference only, don't load unless you're digging into a past decision.

---

## ⚠️ Recent reversals — do NOT act on stale instructions
- **Platform: PC/Mac-first. Mobile NEVER** (console if it succeeds; mobile only on viral success). Mobile would be a *fork*, not a port.
- **Board is 25×14** (locked + implemented). The old 20×11 mobile shrink is dead.
- **In-match UI = the 2026-06-05/06 v3 bounded layout** (recessed surround + bright bordered board, right inspector dock, redesigned victory panel).
- **Pricing: $10–15 (PC band).** Saves = Steam Cloud.
- **No disposable intermediates (NEW 2026-06-06).** We build toward the end state, not throwaway rungs. itch.io beta is DEAD → **closed Steam beta** is the target. Re-sim/anti-cheat and real queue-based multiplayer (Option B) are **pulled forward**, not deferred. See `notes/open_items.md` "session 3".

---

## Name
**"Wend"** (locked). Subtitle carries genre. **Modes: Trials (PVE), Ranked (PVP).**
**Trials scale names: Thread · Weave · Tangle · Snarl · Knot** (1→5, locked 2026-06-06).

## Current focus
**Design session 4 done (2026-06-06): orchestration + Trials lobby + campaign rework specced.** Two new docs + three file edits ready for CC:
- `notes/matchmaking_orchestration.md` (NEW) — the orchestration spine. Coordinator = Nakama match handler; re-sim = async headless-Godot workers. Ranked: queue → forming lobby (fills X/8, **unanimous-of-present vote at 4–7, abstain = no, no timeout**, auto-launch at 8) → instant-join (no ready-check) → run → validate (re-sim authoritative) → settle → teardown. Speed-beats-quality matching (safe because LP is MMR-anchored). Floor = 4. Post-launch drop = forfeit. Crash = void/no-LP. Trials routes through the same spine minus elimination.
- `design/CAMPAIGN.md` (NEW) — five-mission curriculum (ramp from zero, fixing the inverted old M1), the tutorial-beat system, the ghost-outline build-guidance spec, real tutorial copy. Old 10-mission `.tres` deprecated.
- `design/DESIGN_MODES.md` (EDIT) — Trials reconciled (host launches, no ready-up gate; group size = board, no scoring vote; individual-while-grouped deferred); campaign cut to five w/ pointer to CAMPAIGN.md; PVP nav points at orchestration doc; **40×22→25×14 grid drift flagged**.
- `notes/open_items.md`, `STATE.md` (EDIT) — backlog + state updated.

**Earlier (session 3): the MP + leaderboard spine** — `notes/resim_contract.md`, `leaderboard_schema.md`, `ghost_ladder.md`, `leaderboard_ui_spec.md` + mockups. Identity: Steam auth → Nakama, one identity, display name = Steam persona.

## Next step
- **CC — sim determinism conversion: DONE ✅ (2026-06-07).** The re-sim prerequisite (§5) is built and verified:
  - **§5.1 cross-platform float test:** floats bit-identical across Win/Mac/Linux-glibc → built on `float`, no fixed-point. Probe `src/tools/float_probe.gd` + CI guard `.github/workflows/float-probe.yml`; evidence `notes/float_probe_results.md`. (Caveat: if the prod re-sim server is musl/Alpine, add a musl CI leg — glibc-only doesn't clear musl's libm.)
  - **Fixed logical tick:** all sim subsystems now stepped by one fixed-timestep clock in `match_coordinator.gd` (`SIM_DT`, `sim_tick`, accumulator + `MAX_STEPS_PER_FRAME`). Towers/spawner/projectiles/mobs no longer self-`_process` — they expose `sim_step()` and are driven in a fixed order by `BoardState.sim_step` (spawn→towers→projectiles→mobs). Clients still sim locally (entity-step on every machine; clock host-only) so netcode is preserved.
  - **Seeded RNG, ordered draws:** the crit roll (was global `randf()`) now uses one per-match `coordinator.rng`, drawn in board→placement order. Only combat roll, so "all combat rolls seeded" is satisfied.
  - **Tick-based build timer:** `build_ticks_left` is authoritative; `build_time_left` (sec) is just the HUD mirror.
  - **Verified:** `src/tools/sim_harness.gd` (headless, tick-driven) runs a full 13-round match, **byte-identical across 2 runs**, 0 errors, build-timer auto-expiry exercised. Build-phase length proven not to leak into combat outcome.
- **CC — record capture + re-sim runner: DONE ✅ (2026-06-07).** resim_contract §2/§4/§7 built and round-trip verified:
  - **Record capture:** `coordinator.{record_enabled, input_log, map_ref, ruleset_version}` + `log_input(seat, action)` (stamps `sim_tick`) + `make_record()`. Capture sites: `build_controller._place_tower`/`_sell_tower_at_cell` (via `_log_action`), `tower.upgrade`, and `request_start_now`/`set_board_ready` (start/vote_start, §9.2). map_loader wires `sim_seed = map.seed`, `map_ref`, `record_enabled = true`.
  - **Re-sim runner:** `src/scripts/resim.gd` — rebuilds the map from `map_ref`, builds a headless match (recording off), replays the tick-tagged log through the same board entry points, derives per-board score.
  - **Round-trip verified** (`sim_harness.gd`, now a capture→re-sim test): a 13-round match with 42 logged actions across rounds (incl. a round-2 placement at tick 3559) re-sims to the **exact same score** (dmg=69962, kills=485). This is the keystone property — the leaderboard number is the re-sim's, and it matches honest play.
- **CC — wire outputs: DONE ✅ (2026-06-07).** `SceneManager.report_match_result` now records the **re-sim-derived** score, never the live client tally: it re-sims `active_coordinator`'s record (set in `main.gd`) and writes that to SaveData (campaign medal / PVE best). The live tally is advisory/UX only. A mid-match bow-out logs an `end` marker so re-sim scores the partial (new `end` action — extends §9.2, flagged in `resim_contract.md` for review). **Verified** (`sim_harness.gd`): handed an inflated claim of 99,999,999, SaveData stored the honest 69,962 — "you can't write score = 9,999,999." Locally the re-sim runs client-side as the server stand-in + a determinism self-check (`push_warning` if it ever disagrees).
  - **Remaining (resim_contract §10):** solo-log **legality check** (§4.1 — gold/empty-cell/valid-target/supply validation before trusting a *submitted* log; the re-sim assumes a legal log) · **record serialization/submit** (encode to bytes for the Trials submit path; currently an in-memory Dictionary) · **Ranked placement** still reads the live coordinator (authoritative for offline; networked host-side re-sim is a later MP task). Also: wire the real server seed into `sim_seed` (today = map.seed); bot upgrade-pick uses unseeded `randi()` (`bot_controller.gd:154`) — fine, bot matches are never re-simmed.
  - **Needs a human:** real interactive playtest to confirm the live (frame-accumulator) path *feels* right — tick logic is exhaustively verified but the in-app UI/fast-forward flow wasn't driven headless.
- **CC label-pass (mechanical):** Scale 1–5 → Thread/Weave/Tangle/Snarl/Knot across `design/DESIGN_MODES.md` + `design/VISUAL_SYSTEM.md`; remove the Trials "go home?" prompt. (Deliberately not done at wrap to avoid full-rewrite drift.)
- **CC — campaign rebuild:** five missions per `design/CAMPAIGN.md`; deprecate old `levels/campaign/` `.tres`; build the tutorial-beat system (schema reopen, runtime shape CC's call) + ghost-outline overlay.
- **Design — remaining big pieces:** juice/game-feel pass · Steam closed-beta mechanics · season-pass numbers · GTM. No design piece is currently blocking CC — the orchestration + campaign specs give CC a full plate.
- Still needs two humans: a real 2-client cross-network match (targets the end-state stack).

## Recently touched files
- `src/scripts/match_coordinator.gd` — fixed-step sim clock + seeded rng + tick build timer + record capture
- `src/scripts/round_manager.gd` — `BoardState.sim_step` ordered stepping + projectiles array
- `src/scripts/{tower,spawner,projectile,mob}.gd` — `_process`→`sim_step` (externally driven); tower logs upgrades
- `src/scripts/build_controller.gd` — logs place/sell actions (`_log_action`)
- `src/scripts/map_loader.gd` — wires `sim_seed`/`map_ref`/`record_enabled` + `_map_ref_for`
- `src/scripts/resim.gd` — NEW (authoritative re-sim runner; honors `end` marker)
- `src/scripts/scene_manager.gd` — score write reads from re-sim (`_authoritative_score`, `active_coordinator`)
- `src/scripts/main.gd` — sets `active_coordinator` for authoritative scoring
- `src/tools/sim_harness.gd` — NEW (determinism + re-sim round-trip + anti-cheat wiring regression harness)
- `src/tools/float_probe.gd` — NEW (§5.1 cross-platform float probe)
- `.github/workflows/float-probe.yml` — NEW (matrix CI determinism guard)
- `notes/float_probe_results.md` — NEW (float test result: floats safe ✅)
- `notes/matchmaking_orchestration.md` — NEW (orchestration spine)
- `design/CAMPAIGN.md` — NEW (five-mission rework + tutorial beats + ghost outline)
- `design/DESIGN_MODES.md` — EDIT (Trials reconciled, campaign cut to five, grid drift flagged)
- `STATE.md`, `notes/open_items.md` — updated this session

## Open questions / blocked on
Full per-item status in `notes/open_items.md`. Active design: juice/game-feel pass · season-pass numbers · Steam closed-beta mechanics · GTM. CC chores: determinism (first job) · scale-name label-pass · campaign rebuild. Config-level: leaderboard reset anchors (proposed UTC), season length; queue escalation timings + join-window (dials, need telemetry). Blocked on data: B/S/G calibration, PVP seed-convergence, economy re-tune + campaign tuning integers for 25×14. Parked: individual-while-grouped Trials scoring, Ranked ready-check, crash match-reconstruction.
