# Locked decisions — Wend

Must-not-reverse calls. Promoted here so STATE stays small and open_items holds only OPEN
work. Don't re-litigate these unless the relevant thread is explicitly reopened. Newest locks
near the top of each group; date in parens is when it locked.

> **History:** the full reasoning behind each lock lives in the archived session wraps
> (`STATE_ARCHIVE.md`) and the per-system design docs. This file is the index of conclusions.

---

## Product / platform
- **PC/Mac-first. Mobile NEVER** (console if it succeeds). Mobile would be an incompatible *fork*, not a port (different board / leaderboard / game). (2026-06-05)
- **Pricing: $10–15, one-time premium. No microtransactions.** Saves = Steam Cloud. (2026-06-05)
- **Distribution = Steam.** itch.io is dead. No itch/zip hack for the beta — closed Steam beta is the target. (2026-06-06)
- **No disposable intermediates.** Build toward the end-state architecture; don't design throwaway rungs. Staged bring-up for failure isolation is a CC/debug concern, not a reason to lock disposable designs. (2026-06-06)

## Name & vocabulary
- **Name = "Wend"** (Steam-clear). Genre lives in a subtitle/tagline, not the name. (2026-06-05)
- **Modes: Trials (PVE) · Ranked (PVP).** (2026-06-05)
- **Trials scale names: Thread · Weave · Tangle · Snarl · Knot** (1→5). (2026-06-06)
- **"Menu" not "Pause"** for the in-match button — Ranked cannot be paused.
- **Ratings = 1/2/3 stars, never medals.** No bronze/silver/gold naming for campaign/Trials (the `*_threshold` fields are the star cutoffs). Medal icons don't exist in the asset pack. (Note: Ranked *tier* names Stone→Masters are a separate system and stand — see Ranked.)
- **No em-dashes in game copy** (user-facing strings). Internal design docs are exempt.

## Core design (pillars)
- **Single-tower mazing is a PILLAR** (Steelman B, locked — not re-litigated). One tower type, one mob type; depth from maze geometry + zone placement + upgrade allocation. (2026-06-05)
- **PVE (Trials) is the spine; PVP (Ranked) is a real shipping ambition, not optional fluff** (Steelman A). Anti-cheat + queue population are on the launch critical path. (2026-06-05)
- **No tower specialization or evolution** — permanently removed; anti-goal in DESIGN.md unless players explicitly request post-launch.
- **Board = 25×16, universal.** Derived once at the 1080p reference with a 280px right rail; other resolutions scale-and-center the same grid. (Supersedes 40×22, then 25×14.) (2026-06-07)
- **Campaign = 5 missions, ramp from zero, all unlocked.** First Contact · The Long Way · Switchbacks · Hot Spots · The Gauntlet. Curriculum + tutorial-beat + ghost-outline spec in `design/CAMPAIGN.md`. (2026-06-06)
- **In-match layout** = single reserved right rail + maximized board. Authoritative: `design/INMATCH_HUD.md`. (2026-06-07)

## Ranked
- **Tier names = Stone → Bronze → Silver → Gold → Masters** (renamed 2026-06-10 from Bronze/Silver/Gold/Platinum/Masters). **Pure relabel — ladder scale, LP thresholds, demotion buffer, MMR pacing, and resim are all unchanged** (bands keep base 0/100/200/300/400). League-badge art maps 1:1 by name (diamond → Masters; wood unused). Tags: stn/brz/sil/gold/mas.
- **8 solo-queued players; pairwise lives-transfer elimination (Model B, zero-sum from round 1).** LP/MMR ladder, Stone→Masters tiers, seasonal resets (one-tier drop). LP is MMR-anchored net-positive. (2026-06-06)
- **Lobby floor = 4 at launch** (2 for the closed beta, with a documented revert). Forming lobby fills X/8; unanimous-of-present vote launches at 4–7, auto at 8; abstain = no; no timeout. Speed beats quality (aggressive band-widening; cross-tier matches are fine because LP is MMR-anchored). (2026-06-06)
- **Ready-check ships OFF**; additive only if AFK-poisoning shows up. Post-launch drop = forfeit (empty-input board). Coordinator crash = void, no LP. (2026-06-06)
- **Rank does not update mid-run** — lives-transfer resolves at round end, so mid-run rank is undefined.

## Architecture / backend
- **Match authority stays in the headless Godot server; Nakama = meta/matchmaker only** (hands clients a match_id/address). Overrides the orchestration doc's coordinator-in-Nakama suggestion — rewriting the verified GDScript coordinator in Go was wasteful. (2026-06-08)
- **Identity: Steam auth → Nakama.** One identity across modes; display name = Steam persona; no custom account system. Device-auth now, Steam later. (2026-06-06)
- **Anti-cheat = authoritative deterministic re-sim.** Server replays seed + ordered input log → derives the true score; client scores advisory. Source of truth for Trials scores AND Ranked placement. Closes score-injection (not botting — stated boundary). Ruleset versioning = grandfather + reset on balance patch (campaign all-time exempt). (2026-06-06)
- **The whole map is one shared seed — incl. obstacles.** `map_generator.generate(seed)` derives path, checkpoints, AND obstacle placement deterministically; in MP the host issues one `hash(match_id)` seed and broadcasts it, and the resim rebuilds the map from `record[seed]`. So obstacles are deterministic + shared + resim-fed — never client-random. Obstacle ART may vary freely over a *fixed* footprint (cosmetic); varying the *footprint* is gameplay and rides the same seed. (2026-06-10)
- **Backend box: `5.78.110.182`** (CPX31, 4 vCPU / 8 GB / 160 GB, Hetzner `hil`/us-west, Ubuntu). Runs BOTH the Nakama stack (Docker) and the Godot match server (systemd, UDP 8771). Firewall = 3 inbound rules (TCP 22, TCP 7350, UDP 8771). Console/gRPC loopback-bound — SSH tunnel only. Old CPX11 at `ash` (`178.156.171.215`) is deleted. (2026-06-08)
- **Leaderboard board-id schema LOCKED** (`notes/leaderboard_schema.md`): campaign = 10 all-time boards; Trials = 60 ephemeral tournaments `trials_<window>_<scale>_<group>` (purge on reset); Ranked = one global tiered ladder per season `ranked_s<N>`.

## Cosmetics (`design/COSMETICS.md` + `design/SEASON.md`)
- **3 cardinal rules:** 100% visual / zero competitive effect; **skins never enter the sim** (client render layer only — never route equipped-skin state through the match record, it breaks re-sim determinism); cosmetic FX match the default silhouette + duration.
- **Color decision FINAL:** the 7 distinct owned tower sprites force it — growth/investment signal moves to a **base aura ring + size step**, the tower body is a **pure skin slot** (multishot + fire-rate + info box already carry legibility).
- **8 slots:** tower · board biome · zone · projectile+FX · mob (in-match); frame · banner · title (profile flair). Plus the **board-sticker** chrome slot (margin overlay, never over play).
- **Steam supplies name + avatar read-only (Valve-moderated) → zero UGC.** Wend never moderates names/images.
- **source × rarity = how-you-earned-it, never luck/gacha** (common/rare/prestige[never buyable]/paid-DLC; paid disjoint from earnable+prestige).
- **Season = earned-only ladder, no pricing shown.** Season XP comes from **tasks, not playing** (`notes/task_system.md`). Ranked reward bundle = Title + Frame + Rank Sticker (prestige, never on the track).
- **IA = two homes, not three tabs:** Collection (Locker + Codex merged) and Season.

## IP / legal — clear
- Random TD "spiritual successor" framing is clear: game mechanics aren't copyrightable, the SC2 host map is gone, and AMazing TD's live Steam page shares zero expression (name/art/code/layouts) — only the genre overlaps. No clearance issue. (2026-06-09)
