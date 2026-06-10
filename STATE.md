# State — Wend
Last updated: 2026-06-09 (CC session; design state as of 2026-06-10)

## Read order
`claude-rules.md` → `RULES.md` → this file → `notes/open_items.md` (open backlog) →
`notes/decisions.md` (locked calls, don't re-litigate) → only the specific file the task needs.
History/log lives in `STATE_ARCHIVE.md` — reference only, don't load unless digging into a past decision.

## Current focus
Season-pass design fully locked (2026-06-10): point economy, payout chain, S1 tier map, task
system forks. MP arch doc drift resolved. Build queue clear. Hard gate remains Steam identity
verification → App ID → Playtest app.

## Last session (2026-06-09, CC — beta-mode switch + Collection & Season screens)
**Part 1 (beta switch):** `BETA = true` in `index.js` (ranked_s0, `trials_beta_*` ids,
`LOBBY_FLOOR 2`) with mirrored client flags (`LeaderboardService.BETA`,
`SaveData.BUILD_SEASON = 0`); season-0 support through save reconcile, browse, season list,
harnesses. NOT yet deployed to the box (open_items → Deploy/ops). `rescale_campaign.gd`
fixed to 25×16 + marked HISTORICAL (M1–M5 re-authored at 25×16; running it would corrupt them).
**Part 2 (cosmetics screens):** built the two cosmetics homes to the locked mocks —
`cosmetics_catalog.gd` (8 slots + sticker; S1 catalog = defaults + 30-tier track +
Ranked prestige bundle, nothing invented; crystal milestone art imported), SaveData
owned/equipped/season-points/claimed, **Collection** (live loadout preview board + profile
card + slot racks + codex grid w/ silhouettes + import-pending tags) and **Season** (30-tier
track, claim flow grants into Collection, milestones big at 10/20/30, no pricing shown).
Home: season strip is live + opens Season; Collection corner button. `cosmetics_test.tscn`
green (catalog invariants incl. no-prestige-on-track, track math, save round-trip, both
screens build); shots: `collection_shot.png` / `season_shot.png`. XP stays 0 until the
task-system runtime lands (now in open_items).

## Prior session (2026-06-10, design — season-pass numbers + MP arch drift)
Locked the season-pass economy: 30 tiers × 1,000 pts, 8wk, payout chain 120/600/2,400
(×5 daily→weekly, ×4 weekly→monthly). Ceiling ~81,600 vs 30,000 track (~37% capture).
Trials placement bonus: 100/250/500. Task forks closed: score = cumulative, all 15 active.
S1 tier map locked (30-row item table, ~$23 forced spend, all milestone towers $0/owned).
`notes/multiplayer_architecture.md` drift resolved: banner added + two verdict cells fixed
(Steam-relay → "skipped"; Dedicated → "deployed").

## Next step
1. **Steam (blocked on verification):** clears → create Wend App ID → create Playtest app
   (confidential/friends-only; hidden page, manual keys). Confirm entity type at registration.
2. **Human 2-client E2E (Steam-gated):** two real clients Find Match → matchmake → lobby →
   vote → full networked match across networks. First real exercise of the ranked loop.
3. **CC, carried:** deploy the beta module to the box (scp + restart nakama); task-system
   runtime (the Season screen's XP source); apply equipped skins in the real match; import
   S1 track art; catapult PNG export; board-sticker render layer. See `notes/open_items.md`.
4. **Design (own session):** finalize season-pass absolute threshold integers once playtest
   data exists. `notes/season_pass.md` open section tracks this.

## Recently touched files
- **This session (CC, beta switch):** `deploy/nakama/data/modules/index.js`,
  `src/scripts/leaderboard_service.gd`, `src/scripts/save_data.gd`,
  `src/scripts/leaderboard_browse.gd`, `src/scripts/nakama_backend.gd`,
  `src/tools/rescale_campaign.gd` (historical), `src/tools/leaderboard_test.gd`,
  `src/tools/ranked_lp_test.gd`, `src/tools/nakama_backend_test.gd`
- **This session (CC, cosmetics screens):** `src/scripts/cosmetics_catalog.gd` (NEW),
  `src/scripts/collection.gd` + `src/scenes/collection.tscn` (NEW), `src/scripts/season.gd`
  + `src/scenes/season.tscn` (NEW), `src/scripts/save_data.gd` (cosmetics store),
  `src/scripts/home_screen.gd` (live strip + Collection button), `src/scripts/scene_manager.gd`
  (routes), `src/assets/towers/skins/` (crystal trio imported), `src/tools/cosmetics_test.*`
  + `src/tools/cosmetics_shot.*` (NEW)
- `notes/season_pass.md` — rewritten (locked numbers, payout chain, "complete a match" removed)
- `design/SEASON.md` — forks closed + S1 tier map added
- `notes/task_system.md` — forks closed, payouts added
- `notes/multiplayer_architecture.md` — banner + two verdict cells fixed

## Open questions / blocked on
- **Steam:** identity verification pending (2–7 biz days from 2026-06-07). Confirm entity type.
- **Absolute task thresholds** (the X integers) — playtest-gated.
- **Background Creator pack:** confirm it yields path tiles before relying on it for the board slot.
- Full open backlog in `notes/open_items.md`.
