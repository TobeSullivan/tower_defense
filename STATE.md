# State — Wend
Last updated: 2026-06-08

> **Read order:** `claude-rules.md` → `RULES.md` → this file → `notes/open_items.md` (full backlog) → only the specific file the task needs.
> **History:** older session logs were moved to `STATE_ARCHIVE.md` — reference only, don't load unless you're digging into a past decision.

---

## ⚠️ Recent reversals — do NOT act on stale instructions
- **Platform: PC/Mac-first. Mobile NEVER** (console if it succeeds; mobile only on viral success). Mobile would be a *fork*, not a port.
- **Board is 25×14** (locked + implemented). The old 20×11 mobile shrink is dead.
- **In-match UI = the 2026-06-05/06 v3 bounded layout** (recessed surround + bright bordered board, right inspector dock, redesigned victory panel).
- **Pricing: $10–15 (PC band).** Saves = Steam Cloud.
- **No disposable intermediates (NEW 2026-06-06).** We build toward the end state, not throwaway rungs. itch.io beta is DEAD → **closed Steam beta** is the target. Re-sim/anti-cheat and real queue-based multiplayer (Option B) are **pulled forward**, not deferred. See `notes/open_items.md` "session 3".
- **Backend box moved (2026-06-08).** New box = **`5.78.110.182`** (CPX31, 4 vCPU / 8 GB / 160 GB, Hetzner **`hil`/us-west**, Ubuntu). Old CPX11 at `ash` is **deleted**. Any reference to `178.156.171.215` or "resize the box" is stale → see `deploy/nakama/README.md` §0.

---

## Name
**"Wend"** (locked). Subtitle carries genre. **Modes: Trials (PVE), Ranked (PVP).**
**Trials scale names: Thread · Weave · Tangle · Snarl · Knot** (1→5, locked 2026-06-06).

---

## Steam (closed beta) — account status [2026-06-07]
First step toward the closed Steam beta is taken: **Steamworks partner account registered** against the existing personal Steam account (long-standing, Steam Guard on).
- **Entity type:** registered as dev/publisher — individual-vs-company choice NOT confirmed in chat. **CONFIRM** which was selected (matters for tax/bank + later restructure).
- **$100 Steam Direct fee: PAID.** → **30-day release clock is running.** Earliest possible main-game release ≈ **2026-07-07**.
- **Tax (W-9, MI) + bank (checking / USD / US): submitted.** → **Identity Verification Pending, 2–7 business days** (third-party service Lilaham/TaxIdentity). Cannot change tax/bank info or finish account creation until it clears.

**Blocked until verification clears (next actionable Steam step):**
1. Create the **Wend App ID** (the main game app).
2. Create the **Playtest app** off it — Associated Packages & DLC page → set Library capsule image + visible name ("Wend - Playtest") → walk the release-process checklist.

**Open decision to make next session (drives the Playtest config):**
- **Confidential / friends-only:** Playtest App ID + request Standard Release keys + set Playtest Playable + Store Visibility Hidden. No public page, no 2-week wait, nothing leaks. Hand keys directly to testers. *(Likely the right call for a few-friends beta.)*
- **Public Coming Soon page + Playtest signup button:** more setup, reveals Wend publicly, and the store page must be live ≥2 weeks before main-game release — but starts banking wishlists immediately.

(Steam *closed-beta mechanics* design — what the beta build actually contains/tests — remains a separate open design thread; see below.)

---

## Current focus
**Design session 4 done (2026-06-06): orchestration + Trials lobby + campaign rework specced.** Two new docs + three file edits ready for CC:
- `notes/matchmaking_orchestration.md` (NEW) — the orchestration spine. Coordinator = Nakama match handler; re-sim = async headless-Godot workers. Ranked: queue → forming lobby (fills X/8, **unanimous-of-present vote at 4–7, abstain = no, no timeout**, auto-launch at 8) → instant-join (no ready-check) → run → validate (re-sim authoritative) → settle → teardown. Speed-beats-quality matching (safe because LP is MMR-anchored). Floor = 4. Post-launch drop = forfeit. Crash = void/no-LP. Trials routes through the same spine minus elimination.
- `design/CAMPAIGN.md` (NEW) — five-mission curriculum (ramp from zero, fixing the inverted old M1), the tutorial-beat system, the ghost-outline build-guidance spec, real tutorial copy. Old 10-mission `.tres` deprecated.
- `design/DESIGN_MODES.md` (EDIT) — Trials reconciled (host launches, no ready-up gate; group size = board, no scoring vote; individual-while-grouped deferred); campaign cut to five w/ pointer to CAMPAIGN.md; PVP nav points at orchestration doc; **40×22→25×14 grid drift flagged**.
- `notes/open_items.md`, `STATE.md` (EDIT) — backlog + state updated.

**Earlier (session 3): the MP + leaderboard spine** — `notes/resim_contract.md`, `leaderboard_schema.md`, `ghost_ladder.md`, `leaderboard_ui_spec.md` + mockups. Identity: Steam auth → Nakama, one identity, display name = Steam persona.

## Next step

### ▶▶ NEXT SESSION — wire the Godot client to the (now-LIVE) Nakama
**✅ Nakama is DEPLOYED & VERIFIED (2026-06-07, CC over SSH).** Box `5.78.110.182` (CPX31 @ `hil`, Ubuntu 26.04): Nakama healthy, external `:7350` → HTTP 200, **66 boards** (5 campaign + `ranked_s1` + 60 Trials) confirmed in Postgres, `submit_score` RPC registered. Console/gRPC are loopback-bound (tunnel: `ssh -L 7351:localhost:7351 root@5.78.110.182` → `http://localhost:7351`; login in gitignored `deploy/nakama/console_login.local.txt`). Server key lives in the box `.env`; pull it into the gitignored `src/nakama_local.cfg` for the client (USER chose "read from local config"). **Two deploy fixes** (both in `deploy/nakama/README.md` STATUS): Docker wasn't actually installed (CC installed it); compose entrypoint had a YAML folded-scalar bug that dropped `--database.address` (fixed to literal block). **No "confirm it's up" step needed — it's up; build directly against `:7350`.**

Then build, in order (each testable against the live instance):
1. **nakama-godot client + device auth — ✅ DONE & VERIFIED 2026-06-07.** Vendored the `com.heroiclabs.nakama` addon (v3.4.0) into `src/addons/`; added two autoloads — the addon's `Nakama` factory + a **`NakamaService`** autoload (`src/scripts/nakama_service.gd`). NOT named `NakamaClient` (that's the addon's class_name — would shadow it). It reads host/port/scheme/server_key from gitignored `src/nakama_local.cfg` (template `nakama_local.cfg.example`; key pulled from box .env), does **device auth** (stable per-install UUID in SaveData), persists+restores the session token (refresh-aware), and exposes the realtime socket. **Verified headless against the live `:7350`** (`src/tools/nakama_auth_test.{gd,tscn}`, RESULT OK): device auth → real account created → `getAccount` matches → WS socket `Connected!`. Gotcha logged: vendoring a class_name addon needs a one-time `--headless --import` to register the types ([[reference_godot_vendored_addon_import]]).
2. **`NakamaBackend`** (`src/scripts/nakama_backend.gd`) — same `fetch_*` methods as `LeaderboardService.LocalBackend`, reading via `listLeaderboardRecords` / `listTournamentRecords` + `*RecordsAroundOwner` (top-N + neighborhood, schema), writing via the `submit_score` RPC (`encode_record` → b64 → RPC). **Make `LeaderboardService` reads `await`-tolerant** (they're sync now; Nakama is async — call sites await a plain return safely). `set_backend(NakamaBackend)` once a session exists → the 3 leaderboard surfaces light up with real data. The submit path is then real (Trials/campaign scores post on match end).
3. **Matchmaking** (bigger; `matchmaking_orchestration.md`) — ticket + escalation → forming lobby (fill X/8, unanimous-or-auto-at-8, abstain=no, no timeout) → instant-join → hand clients the **Godot match server** address + `match_id`. **Prereq:** the Godot server (`deploy/`) currently runs ONE fixed match — it needs **concurrent matches keyed by match_id** (rooms). Authority stays in Godot (see arch call below); Nakama only matchmakes + points.

Gotchas to remember: no Docker/Node on the dev box (couldn't local-test the Nakama JS — verify on the box); the `submit_score` RPC trusts the client's re-sim'd score for the beta (server-side re-sim worker is deferred launch-hardening, blobs are already stored for it); Steam auth is a separate later task (GodotSteam SDK).

### ✅ §4.1 legality check (+ record serialization) — DONE 2026-06-08
The re-sim now **rejects tampered logs**, closing the second anti-cheat half (it already closed score injection; this closes *illegal* logs). All in `src/scripts/resim.gd` + the submit path, verified headless.
- **`_apply` validates every action at its tick** against the replayed authoritative state and returns a reason on failure (nothing is applied when illegal): `place` (bool of `bot_place_tower` = affordability + `_is_valid_placement`), `sell` (`_sell_tower_at_cell` false ⇒ no tower), `upgrade` (tower exists + `can_upgrade` not-maxed + `can_afford` — previously force-spent), unknown action type, bad seat. **Phase gate:** place/sell/upgrade rejected at any `phase == "run"` tick.
- **`run()` returns `legal: bool` + first-illegal `{tick, seat, action, reason}`**; the first illegal action stops the replay. **Submit path** (`scene_manager._authoritative_score`/`report_match_result`) now returns `{score, legal}` and **writes no score** when illegal.
- **Record serialization:** `Resim.encode_record`/`decode_record` (`var_to_bytes`/`bytes_to_var`; Vector2i cells; ~2.5 KB/record) — the wire/store format for the submit path.
- **Verified** (`src/tools/sim_harness.gd`, 5 checks ✅): honest round-trip (re-sim==live, dmg=54985) · serialize→deserialize identical · two tampered copies rejected (occupied cell ⇒ `illegal_place`; build action at a run tick ⇒ `phase_gate`) · inflated claim ignored · illegal log writes no score. **Note:** the check exposed that the harness had been applying *free* upgrades (direct `t.upgrade()` bypassing gold) — fixed to pay through the real economy, which dropped the honest baseline from an inflated 69962 to a legitimate 54985.

### ▶ Nakama meta backend — IN PROGRESS 2026-06-08 (stack authored; box provisioned @ hil; ✅ DEPLOYED & LIVE 2026-06-07 — client wiring is next)
Bringing the leaderboard service's backend online (and, after, matchmaking). **Decisions (2026-06-08):** self-host Nakama on a dedicated Hetzner box — **`5.78.110.182`, CPX31 (4 vCPU / 8 GB), `hil`/us-west** (moved off the old CPX11/2 GB at `ash`, which was too tight for Nakama+Postgres next to the match sim; Heroic Cloud rejected on cost ~3–5×). **Device-auth first, Steam later.** Scope = **leaderboards + matchmaking** (leaderboards first).
- **Architecture call (resolves a doc conflict):** match **authority stays in the headless Godot server**; **Nakama = meta/matchmaker only** (it hands clients a `match_id`/address). Picks `remote_beta_plan.md`'s "lower-code" path over `matchmaking_orchestration.md`'s Nakama-Go-handler suggestion — rewriting the verified GDScript coordinator in Go is wasteful. (orchestration doc explicitly allows this: "only where the code runs changes.")
- **CC AUTHORED — `deploy/nakama/`** (ready to deploy, not yet live): `docker-compose.yml` (Postgres 16 + Nakama 3.22.0, private Postgres, ports 7349/50/51), `data/modules/index.js` (JS runtime — idempotently creates **5 campaign leaderboards + ranked_s1 + 60 Trials tournaments** per `leaderboard_schema.md` with UTC reset crons, plus an authoritative **`submit_score` RPC** that writes server-side + stashes the match record blob for the later re-sim worker — the real wire format, validator deferred = "no disposable intermediates"), `.env.example`, `.gitignore`, `README.md` (provision + Docker + deploy + verify). **Couldn't local-test** (no Docker/Node on the dev box) — verified by hand against the 3.x runtime API; real verify is on deploy.
- **✅ USER provisioned the box (2026-06-08):** fresh CPX31 created at `hil` (`5.78.110.182`), firewall `firewall-1` set to 3 inbound rules (TCP 22, TCP 7350, UDP 8771 — all any-IP; console is SSH-tunnel-only, no public 7351). Did **not** rescale — CPX11 is deprecated Gen1 and `ash` had no CPX31 capacity; fresh create + redeploy was cleaner since nothing was wired yet. Old box deleted. **✅ DEPLOY DONE (CC, 2026-06-07, over SSH):** Docker installed (29.5.3), stack uploaded to `/opt/wend-nakama`, `.env` generated (random secrets, perms 600), `docker compose up -d` → healthy, 66 boards verified, `:7350` public-reachable. Fixed a compose folded-scalar bug that crash-looped Nakama. Then **CC builds** (against the live instance so it's testable): the nakama-godot client + device auth (`NakamaClient` autoload) → a **`NakamaBackend`** for `LeaderboardService` (reads via list/around-owner, writes via `submit_score`) → `set_backend()` it and the 3 leaderboard surfaces light up with real data → then **matchmaking** (ticket→forming-lobby→hand off to the Godot server, which then needs concurrent-match support).
- **CC deploy-time hardening (small, `notes/open_items.md` → Deploy/ops):** bind the Nakama console to loopback in `docker-compose.yml` (`127.0.0.1:7351:7351`) on the first deploy pass — tunnel-only even if the firewall is misconfigured. 7350 stays public.

### ✅ Leaderboard UI surfaces (3 of 4) + data-service seam — DONE 2026-06-08
Built `notes/leaderboard_ui_spec.md` Surfaces 1/3/4 against a backend-abstracted service — **the seam Nakama plugs into with zero UI rework.**
- **`src/scripts/leaderboard_service.gd`** (NEW): the single read API every surface uses. Owns store-independent logic (board-id naming `trials_<window>_<scale>_<group>`, scale/window names, **UTC reset countdowns** per schema §5.1, Ranked tier→band math) and delegates the row fetch to a swappable backend. Ships **`LocalBackend`** — honest: real local best scores (`SaveData`) + live countdowns, **empty competitor lists** (correct pre-server, not a placeholder). `set_backend(NakamaBackend.new())` later lights everything up. Static-only (no autoload).
- **Surface 3 — `leaderboard_browse.gd` (NEW) + scene + home button:** the hub. Category seg Trials/Ranked/Campaign; Trials = window tabs + countdown + group seg + scale pills + ranked rows w/ jump divider + your green row; Ranked = season seg + your-standing card + one continuous tiered-**band** ladder (Masters→Bronze, colored tags); Campaign = per-mission boards. Empty-states where there's no local data. Deep-linkable via `SceneManager.goto_leaderboards(ctx)`.
- **Surface 4 — `pve_select.gd`:** cards renamed Scale 1–5 → **Thread/Weave/Tangle/Snarl/Knot**; inline live-rank chip ("#14 ›") that taps through to that board. (Also satisfies part of the locked scale-name label-pass.)
- **Surface 1 — `match_end_panel.gd`:** Trials-only post-match placement block (board context · "You placed #N today" · neighborhood ±2 · **View full board**), below the tier strip; panel now sizes to content. Wired via `match_end.lb_ctx` from map_loader (PVE only; campaign unchanged).
- **Deferred — Surface 2 (Ranked post-match LP/placement):** needs the real LP engine + placement from a networked Ranked match; do it with the MP/Nakama work.
- **Verified** (`src/tools/leaderboard_test.{gd,tscn}`, headless, **26 checks ✅**): service logic (naming/bands/countdowns) · LocalBackend honesty (empty vs own-entry) · browse renders all 3 categories with an injected sample backend (jump divider, category/selection switches) · entry points (select builds; PVE match-end gets lb_ctx + renders rows; campaign does not). Screenshots (`leaderboard_shot`) eyeballed vs mockups. ghost_ladder/campaign_verify/sim_harness still green.
- **`ui_style.gd`:** added public `flat_box()` for one-off row/tag surfaces.

### ✅ Ghost ladder (in-match target display) — DONE 2026-06-08
Built `notes/ghost_ladder.md` for Trials (PVE). The in-match SCORE pill's target line now climbs a merged ascending ladder instead of medals-only: **named tier → ghost score → your best → TOP**, never asserting a live rank in-match.
- **`src/scripts/ghost_ladder.gd`** (NEW, `GhostLadder` RefCounted): `setup(b,s,g, ghosts, own_best)` builds the rung list (named tiers below gold ++ snapshot ghost scores above gold); `target_for(score)` returns `{state,target,label,name}` driving the 4 states; `passed()`/`rung_count()` for the optional counter. **Snapshot source is a stub** — `fetch_snapshot()` returns `[]` (no Nakama yet), so offline play correctly falls through to YOUR BEST / TOP (population-independent by design); the GHOST state lights up unchanged when the backend lands.
- **`hud.gd`** — SCORE pill target line routes through `ghost_ladder` when set (medal icon only in named-tier states; badge text carries GHOST/YOUR BEST/TOP). Persistent **"standings as of match start"** caption (the honesty contract). Campaign (`ghost_ladder == null`) keeps the medal-only target.
- **`map_loader.gd`** — `_build_ghost_ladder(map)` builds it for **PVE only** (own-best from `SaveData.best_pve_score`), assigned to HUD before add_child. **Removed the gold-reached "go home?" win panel for Trials** (`_build_match_ui` now gates `WinPanel` to CAMPAIGN) — a Trials run goes until its rounds are spent.
- **Verified** (`src/tools/ghost_ladder_test.{gd,tscn}`, headless, 19 checks ✅): full climb through all 4 states (sub-gold ghost ignored) · dead-board + brand-new-player fallbacks · passed()/rung_count() · wiring (PVE HUD has a ladder + no win panel; campaign has neither change). campaign_verify + sim_harness still green.
- **Next when MP lands:** point `GhostLadder.fetch_snapshot()` at the cached per-`(map,window,group)` leaderboard read; surface the live-rank reveal on the result screen (the only live number).

### ▶ NEXT SESSION — pick up the remaining resim_contract §10 tail + the two human items
The anti-cheat spine is now complete for solo Trials/PVE (determinism → record → re-sim → legality → authoritative write, all verified). What's left:
- **Submit path plumbing** — `encode_record` exists but nothing calls it yet; the actual Trials submit (record → bytes → server/Nakama) is a networked-MP task, sequenced with the orchestration spine.
- **Ranked placement** still reads the live coordinator (authoritative offline; networked host-side re-sim is a later MP task).
- **Wire the real server seed** into `sim_seed` (today = map.seed).

**Two items that want Tobe (not blocking code):**
- **`end`-action nod** — the "locked" §9.2 vocab was extended with an `end` bow-out marker (flagged in `resim_contract.md`). Needs an OK or a different call.
- **Human playtest** — drive a real match interactively; the tick logic is exhaustively verified headless but the live UI/fast-forward path wasn't. De-risks the whole refactor; worth doing before building more on top.

---

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
  - **Remaining (resim_contract §10):** solo-log **legality check** (§4.1) **DONE 2026-06-08** (see "Next step") · **record serialization** **DONE** (`Resim.encode_record`/`decode_record`); the actual **submit** wiring (record → bytes → server) is still a networked-MP task · **Ranked placement** still reads the live coordinator (authoritative for offline; networked host-side re-sim is a later MP task). Also: wire the real server seed into `sim_seed` (today = map.seed); bot upgrade-pick uses unseeded `randi()` (`bot_controller.gd:154`) — fine, bot matches are never re-simmed.
  - **Needs a human:** real interactive playtest to confirm the live (frame-accumulator) path *feels* right — tick logic is exhaustively verified but the in-app UI/fast-forward flow wasn't driven headless.
- **CC label-pass (mechanical):** Scale 1–5 → Thread/Weave/Tangle/Snarl/Knot across `design/DESIGN_MODES.md` + `design/VISUAL_SYSTEM.md`; remove the Trials "go home?" prompt. (Deliberately not done at wrap to avoid full-rewrite drift.)
- **CC — campaign rebuild: DONE ✅ (2026-06-08).** Five-mission curriculum per `design/CAMPAIGN.md`, built + headless-verified:
  - **Maps** live in `src/campaign/` (the doc's `levels/campaign/` path was wrong). `mission_01–05.tres` rewritten to ramp from zero (M1 0CP full-ghost · M2 2CP first-segment ghost · M3 3CP hint ghost · M4 1CP + 4 zones · M5 3CP + 5 zones integration). `mission_06–10.tres` deleted; `CAMPAIGN_MISSION_COUNT`/`CAMPAIGN_MISSIONS`/`campaign_select.LESSONS` trimmed to 5. Tuning + B/S/G are **gentle uncalibrated stubs** (await the 25×14 retune + playtest).
  - **Tutorial-beat schema (reopen → resolved):** an array of `TutorialBeat` sub-resources on `MapResource.tutorial_beats` (mirrors `bonus_zones`/`obstacles`; generated maps leave it empty). `TutorialBeat` = trigger/text/anchor/ghost_cells/blocking.
  - **Runtime (local board, CAMPAIGN only):** `TutorialDirector` maps match signals → 7 triggers (one-shot); `TutorialCallout` = anchored toast + blocking modal (pauses tree for M1's opener); `BuildGuide` = dashed-tile + 40%-alpha-footprint ghost outline, clears a cell on build. No new art. Callouts are positioned (no pointer-arrows yet — deferred polish).
  - **Verified** (`src/tools/campaign_verify.gd`, headless): all 5 parse, every ghost-cell set is a legal maze (path stays open), director/callout/overlay build end-to-end. **Needs a human:** M1's blocking opener (pause→"Got it"→resume) isn't auto-testable headless — confirm in playtest.
- **Design — remaining big pieces:** juice/game-feel pass · Steam closed-beta mechanics · season-pass numbers · GTM. No design piece is currently blocking CC — the orchestration + campaign specs give CC a full plate.
- Still needs two humans: a real 2-client cross-network match (targets the end-state stack).

## Recently touched files
- `src/scripts/match_coordinator.gd` — fixed-step sim clock + seeded rng + tick build timer + record capture
- `src/scripts/round_manager.gd` — `BoardState.sim_step` ordered stepping + projectiles array
- `src/scripts/{tower,spawner,projectile,mob}.gd` — `_process`→`sim_step` (externally driven); tower logs upgrades
- `src/scripts/build_controller.gd` — logs place/sell actions (`_log_action`)
- `src/scripts/map_loader.gd` — wires `sim_seed`/`map_ref`/`record_enabled` + `_map_ref_for`
- `src/scripts/resim.gd` — authoritative re-sim runner; honors `end` marker; **§4.1 legality (`_apply` validates + returns reason, phase gate, `legal`/`illegal` in `run()`) + `encode_record`/`decode_record`** (2026-06-08)
- `src/scripts/scene_manager.gd` — score write reads from re-sim; **`_authoritative_score` returns `{score, legal}` and the submit path writes no score on an illegal log** (2026-06-08)
- `src/scripts/main.gd` — sets `active_coordinator` for authoritative scoring
- `src/tools/sim_harness.gd` — determinism + round-trip + **legality/serialize/reject** regression harness; **upgrades now pay through the real economy** (2026-06-08)
- `src/tools/float_probe.gd` — NEW (§5.1 cross-platform float probe)
- `.github/workflows/float-probe.yml` — NEW (matrix CI determinism guard)
- `notes/float_probe_results.md` — NEW (float test result: floats safe ✅)
- `notes/matchmaking_orchestration.md` — NEW (orchestration spine)
- `design/CAMPAIGN.md` — NEW (five-mission rework + tutorial beats + ghost outline)
- `design/DESIGN_MODES.md` — EDIT (Trials reconciled, campaign cut to five, grid drift flagged)
- `STATE.md`, `notes/open_items.md` — updated this session

**Backend box move (2026-06-08):**
- `deploy/nakama/README.md` — EDIT (§0 resize→fresh-create at `hil`; firewall = 3 public rules + SSH-tunnel for console + loopback-bind TODO; new IP `5.78.110.182` throughout)
- `notes/open_items.md` — EDIT (new Deploy/ops section: box move recorded + CC loopback-bind task; beta_brief stale-framing flagged in Drift/audit)
- `notes/beta_design_brief.md` — EDIT (IP swap only — `178.156.171.215`→`5.78.110.182`; stale itch.io/Steam framing left for next audit)
- `src/scripts/lobby.gd` — EDIT (CC: `DEFAULT_SERVER` IP swap, one-line constant)

**Campaign rebuild (2026-06-08):**
- `src/resources/tutorial_beat.gd` — NEW (beat sub-resource: trigger/text/anchor/ghost_cells/blocking)
- `src/resources/map_resource.gd` — EDIT (`tutorial_beats: Array` field)
- `src/scripts/tutorial_director.gd` — NEW (signals → 7 triggers, one-shot)
- `src/scripts/tutorial_callout.gd` — NEW (anchored toast + blocking modal)
- `src/scripts/build_guide.gd` — NEW (dashed-tile + footprint ghost outline)
- `src/scripts/map_loader.gd` — EDIT (instantiates director/callout/guide for local CAMPAIGN board)
- `src/campaign/mission_01–05.tres` — REWRITTEN (five-mission ramp + beats); `mission_06–10.tres` DELETED
- `src/scripts/scene_manager.gd` — EDIT (CAMPAIGN_MISSIONS/COUNT → 5)
- `src/scripts/campaign_select.gd` — EDIT (LESSONS → 5, grid is now one row)
- `src/tools/campaign_verify.{gd,tscn}` — NEW (headless resource+maze+director verifier)

## Open questions / blocked on
Full per-item status in `notes/open_items.md`. Active design: juice/game-feel pass · season-pass numbers · Steam closed-beta mechanics · GTM. CC chores: determinism (first job) · scale-name label-pass · campaign rebuild. Config-level: leaderboard reset anchors (proposed UTC), season length; queue escalation timings + join-window (dials, need telemetry). Blocked on data: B/S/G calibration, PVP seed-convergence, economy re-tune + campaign tuning integers for 25×14. Parked: individual-while-grouped Trials scoring, Ranked ready-check, crash match-reconstruction.

**Steam (ops):** identity verification pending (2–7 biz days, started 2026-06-07) — blocks App ID + Playtest creation. Confirm entity type chosen at registration. Decide confidential-keys vs. public-Coming-Soon for the Playtest.
