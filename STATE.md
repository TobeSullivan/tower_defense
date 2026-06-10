# State — Wend
Last updated: 2026-06-10

## Current focus
S1 cosmetic + season-pass asset sourcing — **audit complete this session.** Sourcing locked at
$29.35 (Suburbia $19.95 + ice/fireball milestone FX $9.40). Implementation handed to CC.

## Last session (2026-06-10, design)
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

## Next step
1. **CC, S1 implementation** (see `notes/open_items.md` "S1 cosmetic sourcing"). **Done 2026-06-10:**
   Suburbia ground (red-brick) + retag T26; Forest (baked pine recolor); obstacle determinism gate
   CLEARED. **Remaining:** footprint-tag Suburbia props + build the obstacle library; bespoke FX
   (fireball/ice) + owned-bench FX; mob recolors off undead; aquatic-mob render check; apply equipped
   skins in the real match. **Beach BLOCKED** — Tiki art not uploaded.
2. **CC, ranked rename — DONE 2026-06-10.** Stone/Bronze/Silver/Gold/Masters across
   `leaderboard_service`/`cosmetics_catalog`/`leaderboard_browse` + all tests + docs; promoted to
   `decisions.md`. (`ghost_ladder.md` correctly excluded — its Bronze/Silver/Gold are star medals.)
3. **Steam (blocked on verification):** clears → create Wend App ID → create Playtest app
   (confidential/friends-only; hidden page, manual keys). Confirm entity type at registration.
4. **Design (own session):** finalize season-pass absolute threshold integers once playtest data
   exists (`notes/season_pass.md`).

## Recently touched files
- `design/SEASON.md` — Source column re-priced to full freight; Suburbia swap; spend → $19.95
- `notes/board_obstacle_model.md` — NEW; path/ground architecture + obstacle seeding contract
- `notes/asset_buy_list.md` — rewritten to the post-audit reality
- `notes/open_items.md` — S1 sourcing CC handoff + ranked rename merged in
- (CC, prior) `cosmetics_catalog.gd`, collection/season screens, task-system runtime

## Open questions / blocked on
- **Steam:** identity verification pending (2–7 biz days from 2026-06-07). Confirm entity type.
- **Aquatic-mob perspective** — fish/starfish/hammerhead read on a top-down board? CC render check.
- **Absolute task thresholds** (the X integers) — playtest-gated.
- Full open backlog in `notes/open_items.md`.
