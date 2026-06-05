# Season pass — design note

Captured 2026-06-05. Framework + a worked example. Numbers are **soft/proposed**, to tune.

## Locked
- Free pass. **Cosmetic only, no power.** No premium tier, no microtransactions.
- Progress via a milestone/point chain (battle-pass structure).
- Cosmetic-pass tiers are **independent** of the Bronze/Silver/Gold damage thresholds.
  The damage thresholds can *feed* points ("hit Gold on M4 → +X points"), but the pass
  tiers themselves are point-count gates. Don't entangle the two systems.

## Gating decisions (numbers fall out of these)
1. **Season length.** Lean **8 weeks** (cadence without whiplash for a small pool).
   Quarterly (13 wk) = lower art load per season. Pick on art budget, not engagement theory.
2. **Reward tier count.** Standard is 40–50; with cosmetic-only + solo-dev art, **~30**
   is plenty and cuts art load by a third.
3. **Daily/weekly quest layer y/n.** Needed as a renewable point source (and a retention
   hook). Lean yes, light.

## Worked example (8-week season, 30 tiers)
Target curve: an engaged player (~30 min/day) clears all 30 with a week to spare; a
twice-a-week casual lands ~60–70% through. Total pass ≈ **30,000 pts** (~535/day available;
players capture a fraction).

Point sources:
- Complete a match: **50** (self-capping)
- Daily quests (3/day; "play 2 PVE", "100 kills", "post a score"): **150 each** (≈450/day)
- New personal best on a leaderboard: **100**, once per map per window
- Placement bonuses at window close (top 100 / top 10 / #1): **100 / 250 / 500**

Flat **1,000 pts/tier** keeps it legible. Placement bonuses are the only skill-based income —
correct for a free pass: reward showing up, don't gate cosmetics behind being good.

## Rewards (cosmetic, visible to others in lobbies/spectate)
Tower skins, projectile skins, profile flair, **season board** (tier + season number).
Masters players show their final rank number permanently ("162nd Masters, Season 1").

## Open
- Lock season length + tier count (art budget).
- Daily-quest system: build or skip.
- Exact point values once the above are set.
- PVP-side: rank-tier-at-season-end → reward mapping (the PVP season uses rank, not points).
