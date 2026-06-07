# Open items — backlog ledger

Living backlog. STATE.md's "Open questions" points here; this is the full picture so STATE
itself stays small.

Status key: **RESOLVED** · **NEAR** · **REC-PENDING** · **DIRECTION-SET** · **UNTOUCHED** ·
**BLOCKED-DATA** · **OWN-SESSION**

---

## Resolved 2026-06-06 (session 4 — orchestration, Trials lobby, campaign rework)
- **Matchmaking + orchestration → LOCKED.** `notes/matchmaking_orchestration.md`. Coordinator = Nakama authoritative match handler (round-barrier relay, many light matches/box); re-sim validation = separate async headless-Godot worker pool. Ranked spine: queue → **forming lobby** (fills X/8; unanimous-of-present vote launches at 4–7, abstain = no, **no timeout/backstop**; auto-launch at 8) → instant-join (no ready-check) → run + re-sim collection → resolve → validate (re-sim authoritative) → settle → teardown. **Speed beats quality** — aggressive band-widening, Master-vs-Silver fine *because LP is MMR-anchored*. Floor = 4. LP independent of lobby size. Post-launch drop = forfeit (empty-input board, goes with/without you). Coordinator crash = void, no LP. Ready-check ships **off**, additive if AFK-poisoning appears.
- **Trials group lobby → RESOLVED** (was UNTOUCHED; turned out mostly pre-planned in `DESIGN_MODES.md`). Invite-only co-op, **host launches unilaterally when they want** (dropped the doc's "ready-up" gate). **Group size = the board, no vote:** team score for groups (Duo/Trio/Quad), Solo only if solo. Routes through the orchestration spine minus elimination/transfers. Individual-while-grouped scoring **deferred** (see Parked).
- **Campaign teaching rework → LOCKED.** `design/CAMPAIGN.md` (new). The old 10-mission curriculum was **inverted** (M1 exposed everything, M2 stripped back). New: **five missions, ramp from zero** — M1 twist+tower+basic maze (0 CP, full ghost outline), M2 checkpoints (2), M3 checkpoints (3), M4 zones (1 CP, zones isolated), M5 integration (contained non-random "almost a real match"). Crit/multishot taught via upgrades + M5, no dedicated missions. New **tutorial-beat system** (trigger + text, schema reopen, runtime shape = CC's call) and **ghost-outline build guidance** (programmatic overlay, no new art, training wheels off by M4). Real tutorial copy written. Old `levels/campaign/` `.tres` (M1–10) deprecated.
- **DESIGN_MODES.md edited:** ten→five missions + curriculum replaced with pointer to CAMPAIGN.md; Trials scoring-vote section removed; "ready-up" gate dropped from PVE nav; PVP nav points at orchestration doc; **40×22→25×14 grid-figure drift flagged** in the campaign section.

## Resolved 2026-06-06 (session 3 — MP + leaderboard spine)
- **MINDSET: no disposable intermediates.** Build toward the end state, not throwaway rungs we replace next session. The reason staged bring-up exists is *failure isolation* (a CC/debug concern), NOT a reason to design/lock disposable architectures. Consequence: **itch.io beta is DEAD → closed Steam beta is the target**; re-sim/anti-cheat and real queue-based multiplayer (Option B) are **pulled forward**, not deferred. Dedicated server already live is the one validated piece we keep.
- **Re-sim / authoritative scoring → LOCKED.** `notes/resim_contract.md`. Server replays seed + ordered input log → derives true score; client scores advisory only. Source of truth for Trials scores AND Ranked placement. Cheaper than live-authoritative (send a recipe, not a video; bill scales with players, not this choice). Closes score-injection, not botting (stated boundary). Disconnect/reconnect model locked: board keeps playing as left (empty input continuation), "disconnected" badge, eliminated-if-dies-before-return; server-observed timeline, zero advantage to quitting. Ruleset versioning → **grandfather + reset on balance patch** (campaign all-time exempt). Action vocab locked (place/sell/upgrade + start-round: per-round build timer in TICKS, early-start via solo button or MP unanimous `vote_start`, authoritative start = min(timer, last-yes), derivable from log). Map version tags yes.
- **Determinism = CC's FIRST job** (re-sim prerequisite). Sim is NOT deterministic today: towers/spawner/projectiles on `_process(delta)` (framerate-dependent), crit uses global `randf()` (unseeded). Map generation already deterministic from seed (head start). Fix: fixed tick + seeded ordered RNG + tick-based timer. **Cross-platform float test FIRST** (Win/Mac vs Linux server) → floats-OK or fixed-point. Pays off twice (anti-cheat + lockstep MP).
- **Identity → Steam auth → Nakama** (ratified). One identity across modes; display name = Steam persona; no custom account system.
- **Leaderboard board-id schema → LOCKED.** `notes/leaderboard_schema.md`. Campaign = 10 all-time leaderboards. Trials = 60 tournaments `trials_<window>_<scale>_<group>`, **EPHEMERAL (purge on reset — no historical browsing; flat constant storage)**. Ranked = **one global tiered ladder per season** `ranked_s<N>`: all players ranked 1→N, tiers are bands (value = tier_base+LP), current live + past frozen top-N + per-player record + no future. Reset anchors proposed UTC.
- **In-match ghost ladder → LOCKED + BUILT 2026-06-08.** `notes/ghost_ladder.md`. Merges named tiers + leaderboard into one ascending target ladder. Snapshot-at-match-start (shared per board = one cached fan-out; stable rungs). 4 states: named tier → ghost score → own best (empty-board fallback) → TOP. **Never asserts live rank in-match**; live rank only on result screen (Trials rank / Ranked placement + LP + global-rank delta). **Removes the Trials "go home?" prompt** (campaign-ism). **CC BUILT:** `ghost_ladder.gd` (model + state machine) + hud.gd target line/caption + map_loader gating (PVE-only ladder, win-panel→campaign-only); verified `ghost_ladder_test` (19 checks). **Snapshot source is a stub (`fetch_snapshot()`→`[]`) pending Nakama** — falls through to YOUR BEST/TOP offline; GHOST state lights up when the backend lands. Result-screen live-rank reveal not yet built (waits on MP).
- **Leaderboard UI surfaces → LOCKED; 3 of 4 BUILT 2026-06-08.** `notes/leaderboard_ui_spec.md` + 3 mockups in `notes/mockups/`. (1) Trials post-match placement in victory panel ✅; (2) Ranked post-match placement ⏳ (deferred — needs the real LP/placement from networked Ranked); (3) board-browse (Trials ephemeral + countdown; Ranked global tiered ladder; Campaign) ✅; (4) Trials-select cards with inline live rank as tap target ✅. **CC BUILT:** all reads go through `leaderboard_service.gd` (the Nakama seam — backend-abstracted; ships an honest `LocalBackend`: real local best + computed UTC reset countdowns, empty competitor lists pre-server). `leaderboard_browse.gd` (Surface 3 hub, home→Leaderboards), pve_select rename+inline-rank (Surface 4), match_end placement block (Surface 1). Verified `leaderboard_test` (26 checks) + screenshots vs mockups. **When Nakama lands:** add a `NakamaBackend`, `set_backend()` it, and the GHOST/Ranked/Campaign boards + Surface 2 fill in with no UI rework (reads gain `await`).
- **Trials scale names → Thread / Weave / Tangle / Snarl / Knot** (1→5). "Scale N" was placeholder. Ties to the game name (threading a maze). NOTE: labyrinth ≠ harder than maze (it's unicursal/simpler) — names chosen for gradient feel, not technical accuracy. **CC label-pass needed** across `DESIGN_MODES.md` + `VISUAL_SYSTEM.md` (mechanical find-replace; not done at wrap to avoid full-rewrite drift).

## Resolved 2026-06-05 (session 2 — design wrap)
- **Game NAME → "Wend"** (Steam-clear). Genre lives in a subtitle/tagline. Unblocks the Steam page.
- **PVE/PVP player-facing names → "Trials" / "Ranked".** Home hierarchy unchanged.
- **PVE window cadence → keep daily/weekly/monthly (5 maps each).**
- **Vertical slice → the beta/demo plays that role**, not a formal slice.
- **Leaderboard group scoring → per-team, separate boards by size** (solo/duo/trio/quad).
- **PVP LP curve + season specifics → designed.** `notes/pvp_ladder.md` (MMR-anchored net-positive). Numbers are playtest dials; shape locked. Only inactivity decay deferred.
- **Soft caps → governed-by-economy, no change.** Revisit trigger (CC-side, live log): more starting gold, longer runs, higher supply, or board rescale changing gold output.
- **Accessibility / zones → label + color + uniform shape, icons where verified.** speed→fast_forward, slow→waiting, damage→energy; range label-only (no glyph in pack).

## Resolved 2026-06-05 (session 1)
- **Platform fork** → PC/Mac-first; mobile never; console if successful. LOCKED.
- **Pricing band** → $10–15 PC. One-time premium, no microtransactions.
- **Progression persistence** → Steam Cloud (Nakama holds MP/leaderboard profiles).
- **Leaderboard backend** → Nakama. **Frontend** → contextual.
- **In-match UI layout** → approved (recessed surround + bounded arena, flex, right dock).
- **Victory screen** → redesigned.
- **Steelman A** (PVE is the spine, PVP optional) → accepted.
- **Steelman B** (single-tower mazing is a PILLAR) → LOCKED, not re-litigated.
- **Ranked PVP is a real shipping ambition** → confirmed; anti-cheat + queue population on the launch critical path.

## Resolved 2026-06-06 (board/UI build)
- **Board final tile count → 25×14. LOCKED + IMPLEMENTED.**
- **In-match UI rebuild → DONE (v3 bounded layout).** Victory screen redesigned.
- **Soft-caps revisit trigger note:** board-rescale lever fired; economy/supply re-tune still deferred (BLOCKED-DATA) — CC checks live log before any cost bend.

## Direction set — system still undesigned
- **Anti-cheat** — **now has its contract** (`notes/resim_contract.md`: authoritative deterministic re-sim). Remaining build work: the determinism conversion (CC first job) + the re-sim runner + legality checks. No longer a blank "design in its own session."
- **Cosmetic DLC packs** — fork presented (one-time, no gacha). Undecided. Paid never overlaps earnable/prestige.
- **Campaign-as-paid-DLC** — demand-driven posture (ship 5, build more only if asked).

## Untouched — never actually discussed
- **Onboarding for non-SC2 players** — the five-mission campaign rework (`design/CAMPAIGN.md`) now carries the core teaching. Beyond campaign, in-product onboarding is a *launch* concern; for the closed beta, brief testers personally.
- **Community hub** — Discord/subreddit. See `notes/gtm.md`.
- **IP/legal** — Random TD "spiritual successor" framing; confirm clearance.
- **Localization** — defer (English-first niche revival).

## Parked — deferred, additive (not now)
- **Individual-while-grouped Trials scoring** — a future vote letting grouped players each post to Solo instead of team score. Out of near-term design; group size = the board for now.
- **Ranked ready-check** — ships off; flip on only if AFK-poisoning shows up in beta. Additive, costs nothing to defer.
- **Match reconstruction after coordinator crash** — possible (model is re-simmable) but not built; crash voids with no LP instead.

## Blocked on playtest data
- **Bronze/Silver/Gold threshold calibration** (Campaign + PVE).
- **PVP seed-convergence** — shared-seed ranked could converge to identical mazes; eyeball in playtest.
- **Economy/supply re-tune** for the 25×14 board.
- **Campaign tuning integers** — supply/rounds/mobs/zone-mix for the five missions; wait on 25×14 retune + scores.

## Drift / audit
- **40×22 → 25×14 grid figure** — DESIGN_MODES campaign section now flags it; sweep for other stale 40×22 / mission-count references across docs at next audit.

## Own session (large)
- **Juice / game-feel pass** — tweens, particles, hit-pause, shake, road shader. Light taste mockup exists.
- **Full GTM / marketing plan** — Steam page, capsule/tags/trailer, Next Fest/demo, streamer outreach. See `notes/gtm.md`.
- **Steam closed-beta mechanics** — app id ($100), Playtest vs beta branch, Win+Mac export presets, steampipe pipeline.
